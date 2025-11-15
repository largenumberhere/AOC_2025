const std = @import("std");
const prep = @import("prep");
const Allocator = std.mem.Allocator;

pub fn readFileToString(path: []const u8, allocator: Allocator) ![]u8 {
    const pwd = std.fs.cwd();
    const limit = std.Io.Limit.unlimited;
    const content = try pwd.readFileAlloc(path, allocator, limit);
    return content;
}

pub fn delimSplit(alloc: std.mem.Allocator, list: *std.ArrayList([]const u8), string: []const u8, delimiters: []const u8) !void {
    list.clearRetainingCapacity();
    var iter = std.mem.splitSequence(u8, string, delimiters);
    while (iter.next()) |item| {
        if (item.len != 0) {
            try list.append(alloc, item);
        }
    }
}

pub fn allWhitespace(string: []const u8) bool {
    for (string) |chr| {
        if (std.ascii.isWhitespace(chr)) {
            return false;
        }
    }

    return true;
}

pub fn noWhitespace(string: []const u8) bool {
    for (string) |chr| {
        if (std.ascii.isWhitespace(chr)) {
            return true;
        }
    }

    return false;
}

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var stdin_buffer = [_]u8{0} ** 1024;
    const stdin = std.fs.File.stdin();
    // stdin.reader(std.Io, stdin_buffer[0..]);
    // var reader = stdin.reader(, stdin_buffer[0..]);
    // var tio = std.Io.Threaded.init(alloc);
    // const io = tio.io();
    // var reader = std.fs.File.reader(stdin, io, stdin_buffer[0..]);
    // defer tio.deinit();
    // const input = try reader.interface.allocRemaining(alloc, std.Io.Limit.unlimited);

    const file_contents = try readFileToString("input.txt", alloc);
    defer alloc.free(file_contents);

    var lefts = Hashset.init(alloc);
    defer lefts.deinit();
    var rights = Hashset.init(alloc);
    defer rights.deinit();

    var iter = std.mem.splitScalar(u8, file_contents, '\n');
    var line_parts = try std.ArrayList([]const u8).initCapacity(alloc, 2);
    defer line_parts.deinit(alloc);

    while (iter.peek() != null) {
        const line = iter.next().?;

        try delimSplit(alloc, &line_parts, line, " ");
        if (line_parts.items.len != 2) {
            const all_whitespace = allWhitespace(line);
            if (!all_whitespace) {
                std.debug.panic("multi-part string not allowed", .{});
                return error{}{};
            } else {
                break;
            }
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
}

const Hashset = struct {
    map: std.AutoHashMap(i64, i64),
    const Self = @This();

    pub fn init(alloc: std.mem.Allocator) Hashset {
        const set = Hashset{
            .map = std.AutoHashMap(i64, i64).init(alloc),
        };

        return set;
    }

    pub fn deinit(self: *Self) void {
        self.map.deinit();
        // alloc.destroy(self.map);
    }

    pub fn insert(self: *Self, value: i64) !void {
        if (!self.map.contains(value)) {
            try self.map.put(value, 0);
        }

        const ptr = self.map.getPtr(value).?;
        ptr.* += 1;
    }

    pub fn get(self: *Self, value: i64) ?i64 {
        return self.map.get(value);
    }

    pub fn iterator(self: *Self) std.AutoHashMap(i64, i64).Iterator {
        return self.map.iterator();
    }
};
