const std = @import("std");
const Allocator = std.mem.Allocator;
const libaoc = @import("libaoc");
const print = std.debug.print;

const Lines = std.ArrayList([]u8);

fn debug_lines(lines: Lines) void {
    for (lines.items) |line| {
        for (line) |chr| {
            std.debug.print("{c}", .{chr});
        }
        std.debug.print("\n", .{});
    }
}

/// remove leading and trailing lines that are empty or contain only whitespace
fn trim_lines(alloc: Allocator, lines: *Lines) void {
    while (lines.items.len >= 1) {
        if (libaoc.containsNonWhitespace(lines.items[0])) {
            break;
        }
        const line = lines.orderedRemove(0); // horribly inefficient but easy
        alloc.free(line);
    }

    while (lines.items.len >= 1) {
        if (libaoc.containsNonWhitespace(lines.items[lines.items.len - 1])) {
            break;
        }
        const line = lines.orderedRemove(lines.items.len - 1);
        alloc.free(line);
    }
}

const Vec2 = struct {
    x: i64,
    y: i64,

    fn add(self: Vec2, other: Vec2) Vec2 {
        var out = self;
        out.x += other.x;
        out.y += other.y;

        return out;
    }

    fn init_usize(x: usize, y: usize) Vec2 {
        const out = Vec2{
            .x = @intCast(x),
            .y = @intCast(y),
        };

        return out;
    }

    fn in_range(self: *const Vec2, min_bounds: Vec2, max_bounds: Vec2) bool {
        if (self.x < min_bounds.x) {
            return false;
        }

        if (self.y < min_bounds.y) {
            return false;
        }

        if (self.x >= max_bounds.x) {
            return false;
        }

        if (self.y >= max_bounds.y) {
            return false;
        }

        return true;
    }

    fn west(self: Vec2) Vec2 {
        return self.add(Vec2{ .x = -1, .y = 0 });
    }

    fn east(self: Vec2) Vec2 {
        return self.add(Vec2{ .x = 1, .y = 0 });
    }

    fn north(self: Vec2) Vec2 {
        return self.add(Vec2{ .x = 0, .y = -1 });
    }

    fn south(self: Vec2) Vec2 {
        return self.add(Vec2{ .x = 0, .y = 1 });
    }

    fn south_east(self: Vec2) Vec2 {
        return self.add(Vec2{ .x = 1, .y = 1 });
    }

    fn south_west(self: Vec2) Vec2 {
        return self.add(Vec2{ .x = -1, .y = 1 });
    }

    fn north_west(self: Vec2) Vec2 {
        return self.add(Vec2{ .x = -1, .y = -1 });
    }

    fn north_east(self: Vec2) Vec2 {
        return self.add(Vec2{ .x = 1, .y = -1 });
    }

    fn moore_neighbours(self: Vec2) [8]Vec2 {
        const arr = [8]Vec2{ self.north(), self.north_east(), self.east(), self.south_east(), self.south(), self.south_west(), self.west(), self.north_west() };

        return arr;
    }

    fn x_usize(self: Vec2) usize {
        std.debug.assert(self.x >= 0);
        return @intCast(self.x);
    }
    fn y_usize(self: Vec2) usize {
        std.debug.assert(self.y >= 0);
        return @intCast(self.y);
    }
};

const toilet_paper = '@';
const empty = '.';
fn get_accessible(alloc: Allocator, lines: *Lines, list: *std.ArrayList(Vec2)) !void {
    const min_bounds = Vec2{ .x = 0, .y = 0 };
    const max_bounds = Vec2.init_usize(lines.items[0].len, lines.items.len);

    for (0.., lines.items) |y, line| {
        for (0.., line) |x, chr| {
            var filled_neighbours: i64 = 0;
            if (chr != toilet_paper) {
                continue;
            }
            const here = Vec2.init_usize(x, y);

            for (here.moore_neighbours()) |pos| {
                if (!pos.in_range(min_bounds, max_bounds)) {
                    continue;
                }
                if (lines.items[pos.y_usize()][pos.x_usize()] == toilet_paper) {
                    filled_neighbours += 1;
                }
            }

            if (filled_neighbours < 4) {
                try list.append(alloc, here);
            }
        }
    }
}

pub fn main() !void {
    libaoc.check_linkage();

    // debug allocator
    var debug_alloc = std.heap.DebugAllocator(.{}){};
    const alloc = debug_alloc.allocator();
    defer _ = debug_alloc.deinit();

    // stdout
    var print_buffer = [1]u8{0} ** 1024;
    const stdout_fd = std.fs.File.stdout();
    var stdout = stdout_fd.writer(print_buffer[0..]);
    defer stdout.interface.flush() catch {};

    var lines = Lines.empty;
    defer {
        for (lines.items) |item| {
            alloc.free(item);
        }
        lines.deinit(alloc);
    }
    try libaoc.readFileLinesToStrings(alloc, "input.txt", &lines);
    trim_lines(alloc, &lines);

    var accessible_list = std.ArrayList(Vec2).empty;
    defer accessible_list.deinit(alloc);

    var removed: i64 = 0;
    while (true) {
        accessible_list.clearRetainingCapacity();
        try get_accessible(alloc, &lines, &accessible_list);

        for (accessible_list.items) |pos| {
            lines.items[pos.y_usize()][pos.x_usize()] = empty;
            removed += 1;
        }

        if (accessible_list.items.len == 0) {
            break;
        }
    }

    std.debug.print("{}\n", .{removed});
}
