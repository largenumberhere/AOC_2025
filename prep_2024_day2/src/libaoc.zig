const std = @import("std");

pub fn readFileToString(alloc: std.mem.Allocator, path: []const u8) ![]u8 {
    var pwd = std.fs.cwd();
    const file = try pwd.openFile(path, std.fs.File.OpenFlags{});
    defer file.close();
    const str = try file.readToEndAlloc(alloc, std.math.maxInt(usize));

    return str;
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

    pub fn iterator(self: *Self) std.AutoHashMap(i64, i64).Iterator {
        return self.map.iterator();
    }
};
