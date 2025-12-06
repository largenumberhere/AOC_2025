const std = @import("std");
const Allocator = std.mem.Allocator;
const libaoc = @import("libaoc");

const IngredientId = i64;
const Range = struct { min: IngredientId, max: IngredientId };

const Ranges = std.ArrayList(Range);

fn parse_ranges(alloc: Allocator, ranges_lines: []const u8, ranges_out: *Ranges) !void {
    const ParseError = error{
        NoLeft,
        NoRight,
        ExcessChars,
    };

    var ranges_lines_iter = std.mem.splitScalar(u8, ranges_lines, '\n');
    while (ranges_lines_iter.next()) |range_line| {
        var range_line_iter = std.mem.splitScalar(u8, range_line, '-');
        const left_str = range_line_iter.next() orelse return ParseError.NoLeft;
        const right_str = range_line_iter.next() orelse return ParseError.NoRight;
        if (range_line_iter.next() != null) {
            return ParseError.ExcessChars;
        }

        const min = try std.fmt.parseInt(IngredientId, left_str, 10);
        const max = try std.fmt.parseInt(IngredientId, right_str, 10);

        const range = Range{ .min = min, .max = max };

        try ranges_out.append(alloc, range);
    }
}

const Ingredients = std.ArrayList(IngredientId);

fn parse_ingredients(alloc: Allocator, ingredients_lines: []const u8, ingredients_out: *Ingredients) !void {
    var ingredients_lines_iter = std.mem.splitScalar(u8, ingredients_lines, '\n');
    while (ingredients_lines_iter.next()) |ingredients_line| {
        const ingredient = try std.fmt.parseInt(IngredientId, ingredients_line, 10);
        try ingredients_out.append(alloc, ingredient);
    }
}

fn fresh(ingredient: IngredientId, ranges: *const Ranges) bool {
    for (ranges.items) |item| {
        if (ingredient >= item.min and ingredient <= item.max) {
            return true;
        }
    }

    return false;
}

pub fn main() !void {
    libaoc.check_linkage();

    // debug allocator
    var debug_alloc = std.heap.DebugAllocator(.{}){};
    const alloc = debug_alloc.allocator();
    defer _ = debug_alloc.deinit();

    // stdout
    var print_buffer = [1]u8{0} ** 8192;
    const stdout_fd = std.fs.File.stdout();
    var stdout = stdout_fd.writer(print_buffer[0..]);
    defer stdout.interface.flush() catch {};

    try stdout.interface.print("Hello, world\n", .{});

    const file_contents = try libaoc.readFileToString(alloc, "input.txt");
    defer alloc.free(file_contents);

    const trimmed = std.mem.trim(u8, file_contents, "\n ");
    var semgnet_iter = std.mem.splitSequence(u8, trimmed, "\n\n");
    const ranges_lines = semgnet_iter.next().?;
    const ingredients_lines = semgnet_iter.next().?;

    var ranges = Ranges.empty;
    defer ranges.deinit(alloc);
    try parse_ranges(alloc, ranges_lines, &ranges);

    var ingredients = Ingredients.empty;
    defer ingredients.deinit(alloc);
    try parse_ingredients(alloc, ingredients_lines, &ingredients);

    var fresh_count: usize = 0;
    for (ingredients.items) |ingredient| {
        if (fresh(ingredient, &ranges)) {
            try stdout.interface.print("{} is fresh\n", .{ingredient});
            fresh_count += 1;
        }
    }

    try stdout.interface.print("fresh count = {}\n", .{fresh_count});
}
