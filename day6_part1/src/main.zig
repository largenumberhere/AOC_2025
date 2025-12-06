const std = @import("std");
const Allocator = std.mem.Allocator;
const libaoc = @import("libaoc");

const Vec2 = libaoc.Vec2;

const Lines = std.ArrayList([]u8);

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

    try stdout.interface.print("Hello, world\n", .{});

    var lines = std.ArrayList([]u8).empty;
    defer {
        for (lines.items) |line| {
            alloc.free(line);
        }
        lines.deinit(alloc);
    }

    try libaoc.readFileLinesToStrings(alloc, "input.txt", &lines);
    libaoc.trimLines(alloc, &lines);

    std.debug.assert(lines.items.len >= 1);
    const operators_line = lines.items[lines.items.len - 1];
    var operators_iter = std.mem.splitAny(u8, operators_line, " ");

    var number_iters = std.ArrayList(std.mem.SplitIterator(u8, .scalar)).empty;
    defer number_iters.deinit(alloc);
    for (0..lines.items.len - 1) |i| {
        const line = lines.items[i];
        try number_iters.append(alloc, std.mem.splitScalar(u8, line, ' '));
    }

    var outer_tally: i64 = 0;
    while (operators_iter.next()) |op_str| {
        if (op_str.len == 0) {
            continue;
        }

        var inner_tally: i64 = 0;

        for (number_iters.items, 0..) |*iter, iter_number| {
            while (iter.peek().?.len == 0) {
                _ = iter.*.next();
            }

            const current_str = iter.next().?;
            std.debug.print("'{s}'\n", .{current_str});
            const current = try std.fmt.parseInt(i64, current_str, 10);

            if (iter_number == 0) {
                inner_tally = current;
                continue;
            }

            std.debug.assert(op_str.len == 1);
            const op = op_str[0];

            switch (op) {
                '*' => {
                    inner_tally *= current;
                },
                '+' => {
                    inner_tally += current;
                },
                '-' => {
                    inner_tally -= current;
                },
                else => {
                    std.debug.panic("Unsupported operation '{}'\n", .{op});
                },
            }
        }

        outer_tally += inner_tally;
        std.debug.print("op {s}\n", .{op_str});
        std.debug.print("tally = {}\n", .{inner_tally});
    }

    std.debug.print("outer tally = {}\n", .{outer_tally});
}
