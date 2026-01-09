const std = @import("std");
const Allocator = std.mem.Allocator;
const libaoc = @import("libaoc");
const ArrayList = std.ArrayList;

const DebugArena = struct {
    debug_allocator: std.heap.DebugAllocator(.{}),
    arena_allocator: std.heap.ArenaAllocator,

    fn init(arena: *@This()) void {
        arena.debug_allocator = std.heap.DebugAllocator(.{}).init;
        arena.arena_allocator = std.heap.ArenaAllocator.init(arena.debug_allocator.allocator());
    }

    fn deinit(self: *@This()) std.heap.Check {
        self.arena_allocator.deinit();
        const check = self.debug_allocator.deinit();
        return check;
    }

    fn allocator(self: *@This()) Allocator {
        return self.arena_allocator.allocator();
    }
};

const Shape = struct {
    id: usize,
    volume: usize,
    raw_lines: ArrayList([]const u8),
};

const Region = struct {
    width: usize,
    height: usize,
    present_counts: ArrayList(usize),
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

    var raw_lines = std.ArrayList([]const u8).empty;
    var lines_iter = std.mem.splitScalar(u8, shape_string[3..], '\n');
    while (lines_iter.next()) |line| {
        try raw_lines.append(alloc, line);
    }

    var volume: usize = 0;
    for (raw_lines.items) |line| {
        for (line) |chr| {
            if (chr == '#') {
                volume += 1;
            }
        }
    }

    const shape = Shape{ .id = id, .raw_lines = raw_lines, .volume = volume };
    shape_out.* = shape;
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

fn debug_shape(shape: Shape) void {
    std.debug.print("Shape {{ id={}, volume={}, lines = {{\n", .{ shape.id, shape.volume });
    for (shape.raw_lines.items) |line| {
        std.debug.print("  \"{s}\"\n", .{line});
    }
    std.debug.print("}}  }}\n", .{});
}

fn removeAccordingToVolumeHeuristic(alloc: Allocator, current_regions: *ArrayList(Region), shapes: *const ArrayList(Shape)) void {
    var i: isize = @intCast(current_regions.items.len - 1);
    while (i >= 0) : (i -= 1) {
        const region = current_regions.items[@intCast(i)];

        const volume_capacity = region.height * region.width;
        var volume_used: usize = 0;
        for (0.., region.present_counts.items) |present_id, present_count| {
            volume_used += shapes.items[present_id].volume * present_count;
        }

        std.debug.print("region {} takes {} out of {}\n", .{ i, volume_used, volume_capacity });

        if (volume_used > volume_capacity) {
            _ = current_regions.orderedRemove(@intCast(i));
        }
    }
    _ = alloc;
}

pub fn main() !void {
    libaoc.check_linkage();

    var debug_arena: DebugArena = undefined;
    debug_arena.init();
    const alloc = debug_arena.allocator();
    defer _ = debug_arena.deinit();

    const slice = try alloc.alloc(u8, 10);
    if (slice[0] == 0) {
        std.debug.print("{s}", .{"meow"});
    }

    // stdout
    var print_buffer = [1]u8{0} ** 1024;
    const stdout_fd = std.fs.File.stdout();
    var stdout = stdout_fd.writer(print_buffer[0..]);
    defer stdout.interface.flush() catch {};

    const string = try libaoc.readFileToString(alloc, "sample_input.txt");

    var shapes = ArrayList(Shape).empty;
    var regions = ArrayList(Region).empty;
    try appendValues(alloc, string, &shapes, &regions);
    std.debug.print("count before: {}\n", .{regions.items.len});
    removeAccordingToVolumeHeuristic(alloc, &regions, &shapes);
    std.debug.print("count after: {}\n", .{regions.items.len});
}
