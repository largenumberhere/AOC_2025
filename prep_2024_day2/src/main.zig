const std = @import("std");
const libaoc = @import("libaoc.zig");

fn validate_steps(list: *std.ArrayList(i64)) bool {
    if (list.items.len < 2) {
        unreachable;
    }

    var all_ascending = true;
    var all_descending = true;

    for (0..list.items.len - 1) |i| {
        const left = list.items[i];
        const right = list.items[i + 1];

        const abs_diff: i64 = if (left > right) left - right else right - left;

        if (abs_diff > 3 or abs_diff == 0) {
            return false;
        }

        if (right < left) {
            all_ascending = false;
        }

        if (left < right) {
            all_descending = false;
        }

        if (!all_ascending and !all_descending) {
            return false;
        }
    }

    if (!all_ascending and !all_descending) {
        return false;
    }

    return true;
}

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

    const stdout = std.fs.File.stdout();
    var stdout_buffer: [128]u8 = undefined;
    var writer = stdout.writer(stdout_buffer[0..]);

    const input_path = "input.txt";
    var lines = std.ArrayList([]u8).empty;
    defer {
        for (lines.items) |line| {
            alloc.free(line);
        }
        lines.deinit(alloc);
    }
    try libaoc.readFileLinesToStrings(alloc, input_path, &lines);

    var line_parts = std.ArrayList([]u8).empty;
    defer {
        for (line_parts.items) |line| {
            alloc.free(line);
        }
        line_parts.deinit(alloc);
    }
    var line_digits = std.ArrayList(i64).empty;
    defer line_digits.deinit(alloc);

    var valid_count: i64 = 0;
    for (lines.items) |line| {
        for (line_parts.items) |item| {
            alloc.free(item);
        }

        line_parts.clearRetainingCapacity();
        line_digits.clearRetainingCapacity();
        try libaoc.splitSpacesAlloc(alloc, &line_parts, line);

        for (line_parts.items) |item| {
            const number = try std.fmt.parseInt(i64, item, 10);
            try line_digits.append(alloc, number);
        }

        if (line_digits.items.len >= 2) {
            if (validate_steps(&line_digits)) {
                valid_count += 1;
                continue;
            }
        }
    }

    try writer.interface.print("{}\n", .{valid_count});
    try writer.interface.flush();
}
