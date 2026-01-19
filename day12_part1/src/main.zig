const std = @import("std");
const Allocator = std.mem.Allocator;
const libaoc = @import("libaoc");
const ArrayList = std.ArrayList;

const DebugArena = struct {
    debug_allocator: std.heap.DebugAllocator(.{}),
    arena_allocator: std.heap.ArenaAllocator,
    assertions: bool,

    fn initFast(arena: *@This()) void {
        arena.debug_allocator = std.heap.DebugAllocator(.{}).init;
        arena.arena_allocator = std.heap.ArenaAllocator.init(arena.debug_allocator.allocator());
        arena.assertions = false;
    }

    fn initAssert(arena: *@This()) void {
        arena.initFast();
        arena.assertions = true;
    }

    fn deinit(self: *@This()) std.heap.Check {
        self.arena_allocator.deinit();
        const check = self.debug_allocator.deinit();
        return check;
    }

    fn allocator(self: *@This()) Allocator {
        if (self.assertions) {
            return self.debug_allocator.allocator();
        } else {
            return self.arena_allocator.allocator();
        }
    }
};

const Shape = struct {
    const n = 3;
    id: usize,
    lines: ArrayList(std.ArrayList(u8)),
    tmp_buffer: [n][n]u8,

    fn area(self: *const @This()) usize {
        var vol: usize = 0;
        for (self.lines.items) |line| {
            for (line.items) |chr| {
                if (chr == '#') {
                    vol += 1;
                }
            }
        }

        return vol;
    }

    fn init(shape: *Shape, id: usize, lines: ArrayList(ArrayList(u8))) void {
        const tmp = [_][3]u8{ [_]u8{ 0, 0, 0 }, [_]u8{ 0, 0, 0 }, [_]u8{ 0, 0, 0 } };

        shape.* = .{ .id = id, .lines = lines, .tmp_buffer = tmp };
        std.debug.assert(lines.items.len == Shape.n and lines.items[0].items.len == Shape.n);
    }

    fn deinit(shape: *Shape, lines_out: *ArrayList(ArrayList(u8))) void {
        lines_out.* = shape.lines;
    }

    fn debug(shape: Shape) void {
        std.debug.print("Shape {{ id={}, volume={}, lines = {{\n", .{ shape.id, shape.area() });
        for (shape.lines.items) |line| {
            std.debug.print("  \"{s}\"\n", .{line.items});
        }
        std.debug.print("}}  }}\n", .{});
    }
};

const Region = struct {
    width: usize,
    height: usize,
    present_counts: ArrayList(usize),

    fn deinit(self: Region, alloc: Allocator) void {
        var presents = self.present_counts;
        presents.deinit(alloc);
    }

    fn debug(self: *const Region) void {
        std.debug.print("Region width={}, height={}, \n", .{ self.width, self.height });
        for (0.., self.present_counts.items) |present_id, present_count| {
            std.debug.print("   requires {:>3} of shape {:>3} \n", .{ present_count, present_id });
        }
    }
};

fn appendValues(alloc: Allocator, input_file_data: []const u8, shapes: *ArrayList(Shape), regions: *ArrayList(Region)) !void {
    const trimmed = std.mem.trim(u8, input_file_data, "\n\r ");
    var double_newline_iter = std.mem.splitSequence(u8, trimmed, "\n\n");

    while (double_newline_iter.next()) |segment| {
        if (segment[1] == ':' and segment[2] == '\n') {
            var new_shape: Shape = undefined;
            try parseShape(alloc, segment, &new_shape);
            try shapes.append(alloc, new_shape);
        } else if (segment[1] == 'x' or segment[2] == 'x') {
            var regions_iter = std.mem.splitSequence(u8, segment, "\n");
            while (regions_iter.next()) |region_str| {
                var new_region: Region = undefined;
                try parseRegion(alloc, region_str, &new_region);
                try regions.append(alloc, new_region);
            }
        } else {
            std.debug.print("Other '{s}'", .{segment});
            unreachable;
        }
    }
}

fn parseShape(alloc: Allocator, shape_string: []const u8, shape_out: *Shape) !void {
    const id_str = shape_string[0..1];
    const id = try std.fmt.parseInt(usize, id_str, 10);

    var lines = ArrayList(ArrayList(u8)).empty;
    var lines_iter = std.mem.splitScalar(u8, shape_string[3..], '\n');
    while (lines_iter.next()) |line| {
        try lines.append(alloc, ArrayList(u8).empty);
        var last: *ArrayList(u8) = &lines.items[lines.items.len - 1];
        for (0..line.len) |i| {
            try last.append(alloc, line[i]);
        }
    }

    shape_out.init(id, lines);
}

fn parseRegion(alloc: Allocator, region_string: []const u8, region_out: *Region) !void {
    var region_string_iter = std.mem.splitAny(u8, region_string, ":x \n");
    const width_str = region_string_iter.next().?;
    const width = try std.fmt.parseInt(usize, width_str, 10);
    const height_str = region_string_iter.next().?;
    const height = try std.fmt.parseInt(usize, height_str, 10);

    var present_counts = ArrayList(usize).empty;
    while (region_string_iter.next()) |part| {
        if (!libaoc.containsNonWhitespace(part)) {
            continue;
        }

        const count = try std.fmt.parseInt(usize, part, 10);
        try present_counts.append(alloc, count);
    }
    region_out.* = .{
        .width = width,
        .height = height,
        .present_counts = present_counts,
    };
}

/// If the areas of the shapes added up is greater than the region's size, they can't possibly fit in any order
fn retainAccordingToAreaHeuristic(alloc: Allocator, current_regions: *ArrayList(Region), shapes: *const ArrayList(Shape)) void {
    var i: isize = @intCast(current_regions.items.len - 1);
    while (i >= 0) : (i -= 1) {
        const region = current_regions.items[@intCast(i)];

        const region_capacity = region.height * region.width;
        var area_used: usize = 0;
        for (0.., region.present_counts.items) |present_id, present_count| {
            area_used += shapes.items[present_id].area() * present_count;
        }

        if (area_used > region_capacity) {
            current_regions.orderedRemove(@intCast(i)).deinit(alloc);
        }
    }
}

/// If a 3x3 square can fit n times in a region, then n shapes (of the same or smaller size) can fit in it.
/// If not, it is possible but not strictly proven here. Here is is assumed such shapes don't fit.
fn retainAccordingToSquareHeuristic(alloc: Allocator, current_regions: *ArrayList(Region), shapes: *const ArrayList(Shape)) void {
    const template_size = 3;
    _ = shapes; // used for debugging purposes only

    var i: isize = @as(isize, @intCast(current_regions.items.len)) - 1;
    while (i >= 0) : (i -= 1) {
        const region = current_regions.items[@intCast(i)];

        const template_squares_count = (region.width / template_size) * (region.height / template_size);

        var required_shapes_tally: usize = 0;
        for (0.., region.present_counts.items) |shape_id, shape_count| {
            required_shapes_tally += shape_count;
            _ = shape_id;
        }

        const shapes_can_fit = (template_squares_count >= required_shapes_tally);
        if (!shapes_can_fit) {
            current_regions.orderedRemove(@intCast(i)).deinit(alloc);
        }
    }
}

pub fn main() !void {
    libaoc.check_linkage();

    var debug_arena: DebugArena = undefined;
    debug_arena.initFast();
    const alloc = debug_arena.allocator();
    defer _ = debug_arena.deinit();

    // stdout
    var print_buffer = [1]u8{0} ** 1024;
    const stdout_fd = std.fs.File.stdout();
    var stdout = stdout_fd.writer(print_buffer[0..]);
    defer stdout.interface.flush() catch {};

    const string = try libaoc.readFileToString(alloc, "input.txt");
    defer alloc.free(string);

    var shapes = ArrayList(Shape).empty;
    defer {
        for (0..shapes.items.len) |i| {
            var lines: ArrayList(ArrayList(u8)) = undefined;
            shapes.items[i].deinit(&lines);

            for (0.., lines.items) |j, _| {
                lines.items[j].deinit(alloc);
            }
            lines.deinit(alloc);
        }
        shapes.deinit(alloc);
    }

    var regions = ArrayList(Region).empty;
    defer {
        for (0.., regions.items) |i, _| {
            regions.items[i].present_counts.deinit(alloc);
        }
        regions.deinit(alloc);
    }

    try appendValues(alloc, string, &shapes, &regions);
    retainAccordingToAreaHeuristic(alloc, &regions, &shapes);
    retainAccordingToSquareHeuristic(alloc, &regions, &shapes);
    try stdout.interface.print("Count of Regions that may fit: {}\n", .{regions.items.len});
}
