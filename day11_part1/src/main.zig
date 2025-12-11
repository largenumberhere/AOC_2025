const std = @import("std");
const Allocator = std.mem.Allocator;
const libaoc = @import("libaoc");

const HashKey = []const u8;
const HashValue = std.ArrayList([]const u8);

// Should have jused used a std.StringHashMap instead. Adapted from stack overflow answer (SO has Creative commons licence).
// https://stackoverflow.com/questions/77606256/create-a-hashmap-with-a-key-of-struct-with-slices-in-zig
const StringHashmapContext = struct {
    pub fn hash(ctx: StringHashmapContext, key: HashKey) u32 {
        _ = ctx;
        const hasher = std.hash.Fnv1a_32;
        var h = hasher.init();
        h.update(key);
        return h.final();
    }

    pub fn eql(ctx: StringHashmapContext, a: HashKey, b: HashKey) bool {
        _ = ctx;
        return std.mem.eql(u8, a, b);
    }
};

const RulesValue = std.ArrayList([]const u8);
const Rules = std.HashMap(
    HashKey,
    HashValue,
    StringHashmapContext,
    75,
);

pub fn debug_rules(rules: Rules) void {
    var iter = rules.iterator();

    while (iter.next()) |pair| {
        for (pair.value_ptr.*.items) |to| {
            std.debug.print("{s} => {s}\n", .{ pair.key_ptr.*, to });
        }
    }
}

fn traverse(pos: []const u8, rules: *const Rules, count: *usize, destination: []const u8) void {
    // base case: we have reached the end node on this fork, add it to the valid paths count
    if (std.mem.eql(u8, pos, destination)) {
        count.* += 1;
        return;
    }

    // otherwise, visit children
    const values = rules.get(pos).?.items;
    for (values) |to| {
        traverse(to, rules, count, destination);
    }
}

fn append_rules(alloc: Allocator, file_lines: std.ArrayList([]u8), rules: *Rules) !void {
    for (file_lines.items) |line| {
        const name_end = 3;
        const rule_key = line[0..name_end];
        var values = RulesValue.empty;

        var iter = std.mem.splitScalar(u8, line[name_end + 1 ..], ' ');
        while (iter.next()) |item| {
            if (item.len < 1) {
                continue;
            }
            try values.append(alloc, item);
        }

        try rules.put(rule_key, values);
    }
}

pub fn main() !void {
    libaoc.check_linkage();

    // Arena allocator allows the omission of many calls to free in this program
    var debug_alloc = std.heap.DebugAllocator(.{}){};
    defer _ = debug_alloc.deinit();
    var arena = std.heap.ArenaAllocator.init(debug_alloc.allocator());
    defer _ = arena.deinit();
    const alloc = arena.allocator();

    // prepare stdout
    var stdout = block: {
        var print_buffer = [1]u8{0} ** 1024;
        const stdout_fd = std.fs.File.stdout();
        const stdout = stdout_fd.writer(print_buffer[0..]);
        break :block stdout;
    };
    defer stdout.interface.flush() catch {};

    var strings = std.ArrayList([]u8).empty;
    try libaoc.readFileLinesToStrings(alloc, "input.txt", &strings);
    libaoc.trimLines(alloc, &strings);

    var rules = Rules.init(alloc);
    try append_rules(alloc, strings, &rules);

    var count: usize = 0;
    traverse("you", &rules, &count, "out");
    try stdout.interface.print("count = {}\n", .{count});
}
