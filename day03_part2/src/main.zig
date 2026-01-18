const std = @import("std");
const Allocator = std.mem.Allocator;
const libaoc = @import("libaoc");
const print = std.debug.print;

fn parse_char(digit: u8) !i64 {
    const digit_arr = [1]u8{digit};
    const val = try std.fmt.parseInt(i64, digit_arr[0..], 10);
    return val;
}

fn parse_jolts(left_index: usize, right_index: usize, line: []const u8) !i64 {
    const left = try parse_char(line[left_index]);
    const right = try parse_char(line[right_index]);

    return (left * 10) + right;
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

    const file_contents = try libaoc.readFileToString(alloc, "sample_input.txt");
    defer alloc.free(file_contents);

    var lines = std.mem.splitScalar(u8, file_contents, '\n');
    // var joltage_sum: i64 = 0;
    while (lines.next()) |line| {
        if (!libaoc.containsNonWhitespace(line)) {
            continue;
        }

        std.debug.assert(line.len >= 1);

        var list =  std.ArrayList(i64).empty;


        var upper = line.len - 12;
        var cursor = 0;


        for (line) |chr| {
            const value = try parse_char(chr);
            if (value > max_arr[0]) {
                // drop smallest element
                max_arr[0] = value;
                // shuffle up rest of elements
                std.mem.sort(i64, &max_arr, {}, std.sort.asc(i64));
            }
        }
        std.debug.print("{any}\n", .{max_arr});
    }

    // std.debug.print("{}\n", .{joltage_sum});
}
