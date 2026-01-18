const std = @import("std");
const Allocator = std.mem.Allocator;
const libaoc = @import("libaoc");

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

    var lines = std.ArrayList([]u8).empty;
    defer {
        for (lines.items) |line| {
            alloc.free(line);
        }
        lines.deinit(alloc);
    }
    try libaoc.readFileLinesToStrings(alloc, "input.txt", &lines);

    var dial: i64 = 50;
    var zeros_count: i64 = 0;
    std.debug.print("dial = {:3}\n", .{dial});
    const dial_max = 100;
    for (lines.items) |line| {
        if (!libaoc.containsNonWhitespace(line)) {
            continue;
        }

        const direction: i64 = if (line[0] == 'L') -1 else if (line[0] == 'R') 1 else 0;
        std.debug.assert(direction != 0);
        const magnitude = try std.fmt.parseInt(i64, line[1..], 10);
        dial = @mod(dial + (magnitude * direction), dial_max);
        if (dial == 0) {
            zeros_count += 1;
        }

        std.debug.print("dial = {:3} ({s})\n", .{ dial, line });
    }

    std.debug.print("zeros_count = {}\n", .{zeros_count});
}
