const std = @import("std");
const Allocator = std.mem.Allocator;
const libaoc = @import("libaoc");
const assert = std.debug.assert;

const State = struct {
    dial: i64,
    new_zeros: i64,
};

fn check_line(state: State, direction: i64, magnitude: i64) State {
    // if starting at zero do not add 1 zeros if <= 99
    // if ending at zero, add 1 zeros

    const dial_max = 100;
    var dial = state.dial;
    var new_zeros: i64 = 0;
    var tally: i64 = direction * magnitude;

    while (tally > 0) {
        dial += 1;
        tally -= 1;
        if (dial == dial_max) {
            dial = 0;
        }

        if (dial == 0) {
            new_zeros += 1;
        }
    }

    while (tally < 0) {
        dial -= 1;
        tally += 1;
        if (dial == -1) {
            dial = 99;
        }

        if (dial == 0) {
            new_zeros += 1;
        }
    }

    return State{ .dial = dial, .new_zeros = new_zeros };
}

fn part2(lines: []const []const u8) !i64 {
    var dial: i64 = 50;
    var zeros_count: i64 = 0;

    for (lines, 0..) |line, i| {
        _ = i;
        if (!libaoc.containsNonWhitespace(line)) {
            continue;
        }

        const direction: i64 = if (line[0] == 'L') -1 else if (line[0] == 'R') 1 else 0;
        const magnitude = try std.fmt.parseInt(i64, line[1..], 10);
        std.debug.assert(direction != 0);

        const line_result = check_line(State{ .dial = dial, .new_zeros = zeros_count }, direction, magnitude);
        zeros_count += line_result.new_zeros;
        dial = line_result.dial;
    }

    return zeros_count;
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

    var lines = std.ArrayList([]u8).empty;
    defer {
        for (lines.items) |line| {
            alloc.free(line);
        }
        lines.deinit(alloc);
    }

    try libaoc.readFileLinesToStrings(alloc, "sample_input.txt", &lines);

    const zeros_count = try part2(lines.items);
    try stdout.interface.print("{}\n", .{zeros_count});
}
