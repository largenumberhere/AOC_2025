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
    const dial = state.dial;

    const tally = direction * magnitude;

    assert(tally != 0);
    var new_zeros: i64 = 0;
    const full_rotations: i64 = @intCast(@abs(@divTrunc(tally, @as(i64, @abs(dial_max)))));
    const partial: i64 = @intCast(@mod(@abs(tally), @as(i64, dial_max)));
    new_zeros += full_rotations;
    var tmp = (partial * direction) + dial;
    if (tmp >= dial_max) {
        new_zeros += 1;
        tmp -= dial_max;
    } else if (tmp < 0) {
        new_zeros += 1;
        tmp += dial_max;
    }
    if (tmp == 0) {
        new_zeros += 1;
    }

    const new_dial = @mod(tmp, dial_max);
    std.debug.print("{:3} + {:3} -> {:3} ({:3})\n", .{ dial, tally, new_dial, new_zeros });

    return State{ .dial = new_dial, .new_zeros = new_zeros };
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

    try libaoc.readFileLinesToStrings(alloc, "/home/rose/Documents/programming/aoc_2025/day1_part2/sample_input.txt", &lines);

    const zeros_count = try part2(lines.items);
    std.debug.print("zeros_count = {}\n", .{zeros_count});
}

// 6142 is too high
// 5604 too low
