const std = @import("std");
const Allocator = std.mem.Allocator;
const libaoc = @import("libaoc");

pub fn main() !void {
    const Errors = error{
        UnsupportedSymbol,
        UndefinedEdgeCase,
    };

    libaoc.check_linkage();

    // buffer allocator
    const kilobyte = 1024;
    var allocator_backing = [1]u8{0} ** (100 * kilobyte);
    var buffer_alloc = std.heap.FixedBufferAllocator.init(allocator_backing[0..]);
    const balloc = buffer_alloc.allocator();

    // stdout
    var print_buffer = [1]u8{0} ** 8192;
    const stdout_fd = std.fs.File.stdout();
    var stdout = stdout_fd.writer(print_buffer[0..]);
    defer stdout.interface.flush() catch {};

    var lines_list = std.ArrayList([]u8).empty;
    defer {
        for (lines_list.items) |line| {
            balloc.free(line);
        }
        lines_list.deinit(balloc);
    }

    try libaoc.readFileLinesToStrings(balloc, "input.txt", &lines_list);
    libaoc.trimLines(balloc, &lines_list);

    // nb: assumes flat 2d matrix, not a jagged array
    const lines = lines_list.items;
    var splits_tally: i64 = 0;
    for (0..lines.len) |i| {
        for (0..lines[0].len) |j| {
            if (lines[i][j] == 'S' or lines[i][j] == '|') {
                const can_look_down1 = (i < lines.len - 1);
                const down1 = i + 1;
                if (!can_look_down1) {
                    continue;
                } else if (lines[down1][j] == '|') {
                    continue;
                } else if (lines[down1][j] == '.') {
                    lines[down1][j] = '|';
                    continue;
                } else if (lines[down1][j] != '^') {
                    return Errors.UnsupportedSymbol;
                }

                const can_look_down2 = (i < lines.len - 2);
                if (!can_look_down2) {
                    return Errors.UndefinedEdgeCase;
                }

                const can_look_left = j >= 1;
                const can_look_right = j < lines[0].len - 1;
                const left = j - 1;
                const right = j + 1;

                if (can_look_left or can_look_right) {
                    splits_tally += 1;
                }

                if (can_look_left) {
                    lines[down1][left] = '|';
                }

                if (can_look_right) {
                    lines[down1][right] = '|';
                }
            }
        }
    }

    for (lines) |line| {
        try stdout.interface.print("{s}\n", .{line});
    }
    try stdout.interface.print("\n", .{});
    try stdout.interface.print("splits count = {}\n", .{splits_tally});
}
