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

pub fn debug_rules(rules: *Rules) void {
    var iter = rules.iterator();

    while (iter.next()) |pair| {
        for (pair.value_ptr.*.items) |to| {
            std.debug.print("{s} => {s}\n", .{ pair.key_ptr.*, to });
        }
    }
}

const String = []const u8;

// const History = std.ArrayList([]const u8);
const History = struct {
    // inner: std.ArrayList([]const u8),
    const capacity = 64;
    items: [capacity]String,
    len: usize,
    contains_dac: bool,
    contains_fft: bool,
    const empty = History{ .contains_dac = false, .contains_fft = false, .len = 0, .items = undefined };

    fn clone(self: *const History, alloc: Allocator) !History {
        _ = alloc;

        var items: [capacity]String = undefined;
        @memcpy(items[0..], self.items[0..]);
        const history = History{
            // .inner = try self.inner.clone(alloc),
            .contains_dac = self.contains_dac,
            .contains_fft = self.contains_fft,
            .len = self.len,
            .items = items,
        };

        return history;
    }

    fn append(self: *History, alloc: Allocator, value: []const u8) !void {
        std.debug.assert(self.len < 128);
        self.items[self.len] = value;
        self.len += 1;

        _ = alloc;

        if (std.mem.eql(u8, value, "dac")) {
            self.contains_dac = true;
        }

        if (std.mem.eql(u8, value, "fft")) {
            self.contains_fft = true;
        }
    }

    fn deinit(self: *@This(), alloc: Allocator) void {
        // self.inner.deinit(alloc);
        _ = self;
        _ = alloc;
    }
};

export fn debug_history_extern(history_any: *const anyopaque) void {
    const history: *const History = @ptrCast(@alignCast(history_any));

    std.debug.print("History: ", .{});
    var i: usize = 0;
    while (i < history.len) : (i += 1) {
        const his = history.items[i];

        std.debug.print("{s} ", .{his});
    }
    std.debug.print("\n", .{});
}

fn debug_history(history: History) void {
    for (0..history.len, history.items) |_, his| {
        std.debug.print("{s} ", .{his});
    }
    std.debug.print("\n", .{});
}

fn history_contains_dac_and_fft(history: *const History) bool {
    // var contains_dac = false;
    // var contains_fft = false;
    // for (history.items) |item| {
    //     if (std.mem.eql(u8, item, "dac")) {
    //         contains_dac = true;
    //     }

    //     if (std.mem.eql(u8, item, "fft")) {
    //         contains_fft = true;
    //     }

    //     if (contains_dac and contains_fft) {
    //         break;
    //     }
    // }

    return history.contains_dac and history.contains_fft;
}

fn new_history(alloc: Allocator, pre_history: *const History, prev_item: []const u8) !History {
    // var new = try pre_history.clone(alloc);
    // try new.append(alloc, prev_item);
    // return new;

    var new = try pre_history.clone(alloc);
    try new.append(alloc, prev_item);
    return new;

    // var new = History{ .contains_dac = pre_history.contains_dac, .contains_fft = pre_history.contains_fft, .inner = .empty };

    // try new.inner.resize(alloc, pre_history.inner.items.len + 1);
    // try new.inner.appendSlice(alloc, pre_history.inner.items);
    // try new.inner.append(alloc, prev_item);
    // return new;
}

var tmp: usize = 0;

fn traverse(alloc: Allocator, pos: []const u8, rules: *const Rules, count: *usize, destination: []const u8, history: History) !void {
    tmp += 1;
    if (tmp % 100000000 == 0) {
        debug_history(history);
    }

    // base case: we have reached the end node on this fork, add it to the valid paths count
    if (std.mem.eql(u8, pos, destination)) {
        if (!history_contains_dac_and_fft(&history)) {
            return;
        }

        count.* += 1;
        return;
    }

    // otherwise, visit children
    const values = rules.get(pos).?.items;
    for (values) |to| {
        // var next_history = try history.clone(alloc);
        // try next_history.append(alloc, to);
        var next_history = try new_history(alloc, &history, to);

        try traverse(alloc, to, rules, count, destination, next_history);

        next_history.deinit(alloc);
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

    // Arena allocator allows the omission of calls to free in this program
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
    debug_rules(&rules);
    var count: usize = 0;
    try traverse(alloc, "svr", &rules, &count, "out", History.empty);
    try stdout.interface.print("count = {}\n", .{count});
}
