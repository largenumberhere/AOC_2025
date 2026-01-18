const std = @import("std");
const Allocator = std.mem.Allocator;
const libaoc = @import("libaoc");
const print = std.debug.print;

const Range = struct {
    min: []const u8, // inclusive
    max: []const u8, // inclusive
};

fn ceildiv(a: usize, b: usize) usize {
    return @intFromFloat((@ceil(@as(f64, @floatFromInt(a)) / @as(f64, @floatFromInt(b)))));
}

fn iter_range(range: Range, logger: *std.io.Writer) !usize {
    var count: i64 = 0;
    const start = try std.fmt.parseInt(i64, range.min, 10);
    const end = try std.fmt.parseInt(i64, range.max, 10);

    var value = start;
    var arr = [1]u8{0} ** 32;

    while (value <= end) {
        @memset(arr[0..], 0);
        var slice = try std.fmt.bufPrint(arr[0..], "{}", .{value});

        const part1 = slice[0 .. slice.len / 2];
        const part2 = slice[ceildiv(slice.len, 2)..slice.len];
        _ = if (@mod(slice.len, 2) == 0) null else slice[slice.len / 2];

        if (slice.len % 2 == 0) {
            if (std.mem.eql(u8, part1, part2)) {
                try logger.print("in range {s:15} - {s:15}. {:15} is repeated\n", .{ range.min, range.max, value });
                count += value;
            }
        }

        value += 1;
    }

    return @intCast(count);
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

    const file_contents = try libaoc.readFileToString(alloc, "input.txt");
    defer alloc.free(file_contents);
    var iter = std.mem.splitAny(u8, file_contents, "-,");

    var tally: i64 = 0;
    while (iter.peek() != null) {
        const left = std.mem.trim(u8, iter.next().?, " \n");
        const right = std.mem.trim(u8, iter.next().?, " \n");

        const range = Range{ .min = left, .max = right };
        const new = try iter_range(range, &stdout.interface);
        tally += @intCast(new);
    }

    try stdout.interface.print("tally = {}\n", .{tally});
}
