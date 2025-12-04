const std = @import("std");
const Allocator = std.mem.Allocator;
const libaoc = @import("libaoc");
const print = std.debug.print;

const Lines = std.ArrayList([]u8);
const Vec2 = libaoc.Vec2;
const trim_lines = libaoc.trimLines;

const toilet_paper = '@';
const empty = '.';
fn get_accessible(alloc: Allocator, lines: *Lines, list: *std.ArrayList(Vec2)) !void {
    const min_bounds = Vec2{ .x = 0, .y = 0 };
    const max_bounds = Vec2.initUsize(lines.items[0].len, lines.items.len);

    for (0.., lines.items) |y, line| {
        for (0.., line) |x, chr| {
            var filled_neighbours: i64 = 0;
            if (chr != toilet_paper) {
                continue;
            }
            const here = Vec2.initUsize(x, y);

            for (here.mooreNeighbours()) |pos| {
                if (!pos.inRange(min_bounds, max_bounds)) {
                    continue;
                }
                if (lines.items[pos.yUsize()][pos.xUsize()] == toilet_paper) {
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
            lines.items[pos.yUsize()][pos.xUsize()] = empty;
            removed += 1;
        }

        if (accessible_list.items.len == 0) {
            break;
        }
    }

    std.debug.print("{}\n", .{removed});
}
