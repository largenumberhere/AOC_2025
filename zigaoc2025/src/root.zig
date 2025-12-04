//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

pub fn check_linkage() void {}

test "hello" {
    std.debug.assert(true);
}

test "Vec2 test" {
    const vec = Vec2.initUsize(0, 0);
    const vec2 = vec.add(Vec2{ .x = 1, .y = 2 });
    std.debug.assert(vec2.x == 1);
    std.debug.assert(vec2.y == 2);
}

/// remove leading and trailing lines that are empty or contain only whitespace
pub fn trimLines(alloc: std.mem.Allocator, lines: *std.ArrayList([]u8)) void {
    while (lines.items.len >= 1) {
        if (containsNonWhitespace(lines.items[0])) {
            break;
        }
        const line = lines.orderedRemove(0); // horribly inefficient but easy
        alloc.free(line);
    }

    while (lines.items.len >= 1) {
        if (containsNonWhitespace(lines.items[lines.items.len - 1])) {
            break;
        }
        const line = lines.orderedRemove(lines.items.len - 1);
        alloc.free(line);
    }
}

pub const Vec2 = struct {
    x: i64,
    y: i64,

    pub fn add(self: Vec2, other: Vec2) Vec2 {
        var out = self;
        out.x += other.x;
        out.y += other.y;

        return out;
    }

    pub fn initUsize(x: usize, y: usize) Vec2 {
        const out = Vec2{
            .x = @intCast(x),
            .y = @intCast(y),
        };

        return out;
    }

    pub fn inRange(self: *const Vec2, min_bounds: Vec2, max_bounds: Vec2) bool {
        if (self.x < min_bounds.x) {
            return false;
        }

        if (self.y < min_bounds.y) {
            return false;
        }

        if (self.x >= max_bounds.x) {
            return false;
        }

        if (self.y >= max_bounds.y) {
            return false;
        }

        return true;
    }

    pub fn west(self: Vec2) Vec2 {
        return self.add(Vec2{ .x = -1, .y = 0 });
    }

    pub fn east(self: Vec2) Vec2 {
        return self.add(Vec2{ .x = 1, .y = 0 });
    }

    pub fn north(self: Vec2) Vec2 {
        return self.add(Vec2{ .x = 0, .y = -1 });
    }

    pub fn south(self: Vec2) Vec2 {
        return self.add(Vec2{ .x = 0, .y = 1 });
    }

    pub fn southEast(self: Vec2) Vec2 {
        return self.add(Vec2{ .x = 1, .y = 1 });
    }

    pub fn southWest(self: Vec2) Vec2 {
        return self.add(Vec2{ .x = -1, .y = 1 });
    }

    pub fn northWest(self: Vec2) Vec2 {
        return self.add(Vec2{ .x = -1, .y = -1 });
    }

    pub fn northEast(self: Vec2) Vec2 {
        return self.add(Vec2{ .x = 1, .y = -1 });
    }

    pub fn mooreNeighbours(self: Vec2) [8]Vec2 {
        const arr = [8]Vec2{ self.north(), self.northEast(), self.east(), self.southEast(), self.south(), self.southWest(), self.west(), self.northWest() };

        return arr;
    }

    pub fn xUsize(self: Vec2) usize {
        std.debug.assert(self.x >= 0);
        return @intCast(self.x);
    }

    pub fn yUsize(self: Vec2) usize {
        std.debug.assert(self.y >= 0);
        return @intCast(self.y);
    }
};

pub fn readFileToString(alloc: std.mem.Allocator, path: []const u8) ![]u8 {
    var pwd = std.fs.cwd();
    const file = try pwd.openFile(path, std.fs.File.OpenFlags{});
    defer file.close();
    const str = try file.readToEndAlloc(alloc, std.math.maxInt(usize));

    return str;
}

pub fn stringEmpty(string: []const u8) bool {
    return (string.len == 0 or !containsNonWhitespace(string));
}

pub fn readFileLinesToStrings(alloc: std.mem.Allocator, path: []const u8, list: *std.ArrayList([]u8)) !void {
    const string = try readFileToString(alloc, path);
    defer alloc.free(string);

    var lines_iter = std.mem.splitScalar(u8, string, '\n');
    while (lines_iter.next()) |line| {
        const line_copy = try alloc.dupe(u8, line);
        try list.append(alloc, line_copy);
    }
}

pub fn iterCount(comptime T: type, iter_ptr: *T) i64 {
    var count: i64 = 0;
    while (iter_ptr.next()) |_| {
        count += 1;
    }

    return count;
}

pub fn containsWhitespace(string: []const u8) bool {
    for (string) |chr| {
        if (std.ascii.isWhitespace(chr)) {
            return true;
        }
    }

    return false;
}

pub fn containsNonWhitespace(string: []const u8) bool {
    for (string) |chr| {
        if (!std.ascii.isWhitespace(chr)) {
            return true;
        }
    }

    return false;
}

// do not free the items
pub fn splitSpacesAllocConst(alloc: std.mem.Allocator, list: *std.ArrayList([]const u8), string: []const u8) !void {
    var iter = std.mem.splitScalar(u8, string, ' ');
    while (iter.next()) |part| {
        if (part.len == 0) {
            continue;
        }
        if (!containsNonWhitespace(part)) {
            continue;
        }
        try list.append(alloc, part);
    }
}

pub fn splitAlloc(alloc: std.mem.Allocator, list: *std.ArrayList([]u8), string: []const u8, delimiter: []const u8) !void {
    var iter = std.mem.splitSequence(u8, string, delimiter);
    while (iter.next()) |part| {
        if (part.len == 0) {
            continue;
        }
        if (!containsNonWhitespace(part)) {
            continue;
        }

        const part_copy = try alloc.dupe(u8, part);
        try list.append(alloc, part_copy);
    }
}

// free the list items
pub fn splitSpacesAlloc(alloc: std.mem.Allocator, list: *std.ArrayList([]u8), string: []u8) !void {
    var iter = std.mem.splitScalar(u8, string, ' ');
    while (iter.next()) |part| {
        if (part.len == 0) {
            continue;
        }
        if (!containsNonWhitespace(part)) {
            continue;
        }

        const part_copy = try alloc.dupe(u8, part);

        try list.append(alloc, part_copy);
    }
}

pub const AutoHashbag = struct {
    map: std.AutoHashMap(i64, i64),
    const Self = @This();

    pub fn init(alloc: std.mem.Allocator) AutoHashbag {
        const set = AutoHashbag{
            .map = std.AutoHashMap(i64, i64).init(alloc),
        };

        return set;
    }

    pub fn deinit(self: *Self) void {
        self.map.deinit();
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

    pub fn iterator(self: *Self) struct {
        inner: std.AutoHashMap(i64, i64).Iterator,

        pub fn next(iter_self: *@This()) ?struct { key_ptr: *i64, count_ptr: *i64 } {
            const entry = iter_self.inner.next() orelse return null;
            return .{
                .key_ptr = entry.key_ptr,
                .count_ptr = entry.value_ptr,
            };
        }
    } {
        const iter = self.map.iterator();

        return .{ .inner = iter };
    }
};
