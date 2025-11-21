const std = @import("std");
const libaoc = @import("libaoc.zig");
const mvzr = @import("mvzr");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

    // const stdout = std.fs.File.stdout();
    // var stdout_buffer: [128]u8 = undefined;
    // var writer = stdout.writer(stdout_buffer[0..]);

    const input_path = "input.txt";
    const file_contents = try libaoc.readFileToString(alloc, input_path);
    defer alloc.free(file_contents);

    // const reg_str =
    //     \\mul\((\d+)\,(\d+)\)
    // ;
    const reg_str =
        \\(mul\(\d+,\d+\))|(don't)|(do)
    ;

    var reg: mvzr.Regex = mvzr.compile(reg_str).?;
    var reg_iter: mvzr.Regex.RegexIterator = reg.iterator(file_contents);
    var tally: i64 = 0;
    var active: bool = true;
    while (reg_iter.next()) |match| {
        const slice = match.slice;

        const Variants = enum {
            do,
            dont,
            other,
        };

        const variant: Variants = if (std.mem.eql(u8, slice, "do")) .do else if (std.mem.eql(u8, slice, "don't")) .dont else .other;

        if (variant == .do) {
            active = true;
            continue;
        } else if (variant == .dont) {
            active = false;
            continue;
        }

        if (!active) {
            continue;
        }

        var comma_split_iter = std.mem.splitScalar(u8, slice, ',');
        const left = comma_split_iter.next().?;
        const right = comma_split_iter.next().?;

        const left_num_str = left[4..];
        const right_num_str = right[0 .. right.len - 1];

        const left_num = try std.fmt.parseInt(i64, left_num_str, 10);
        const right_num = try std.fmt.parseInt(i64, right_num_str, 10);

        const product = left_num * right_num;
        tally += product;
    }
    std.debug.print("> {}\n", .{tally});
}
