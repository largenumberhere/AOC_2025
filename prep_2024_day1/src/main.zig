const std = @import("std");
// const prep2 = @import("prep2");
const libaoc = @import("libaoc.zig");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

    const arg2 = "input.txt";
    const file_contents = try libaoc.readFileToString(alloc, arg2);
    defer alloc.free(file_contents);

    var line_iter = std.mem.splitScalar(u8, file_contents, '\n');
    var lefts = libaoc.AutoHashbag.init(alloc);
    defer lefts.deinit();
    var rights = libaoc.AutoHashbag.init(alloc);
    defer rights.deinit();
    var line_parts = try std.ArrayList([]const u8).initCapacity(alloc, 2);
    defer line_parts.deinit(alloc);
    while (line_iter.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        line_parts.clearRetainingCapacity();
        try libaoc.splitSpacesAlloc(alloc, &line_parts, line);

        if (line_parts.items.len == 0) {
            continue;
        } else if (line_parts.items.len != 2) {
            for (line_parts.items) |item| {
                std.debug.print("'{s}'\n", .{item});
            }
            return error{InvalidInput}.InvalidInput;
        }

        const left = line_parts.items[0];
        const right = line_parts.items[1];
        try lefts.insert(try std.fmt.parseInt(i64, left, 10));
        try rights.insert(try std.fmt.parseInt(i64, right, 10));
    }

    var lefts_iter = lefts.iterator();
    var tally: i64 = 0;
    while (lefts_iter.next()) |item| {
        const key = item.key_ptr.*;
        const count = item.value_ptr.*;

        const similarity_score = (rights.get(key) orelse 0) * key;
        const item_score = similarity_score * count;
        tally += item_score;
    }

    var buff = [_]u8{0} ** 128;

    const stdout = std.fs.File.stdout();
    var writer = stdout.writer(buff[0..]);
    try writer.interface.print("tally = {}\n", .{tally});
    try writer.interface.flush();

    var lines = std.ArrayList([]u8).empty;
    try libaoc.readFileLinesToStrings(alloc, "input.txt", &lines);
    defer {
        for (lines.items) |line| {
            alloc.free(line);
        }
        lines.deinit(alloc);
    }

    for (lines.items) |line| {
        std.debug.print("line: {s}\n", .{line});
    }
}
