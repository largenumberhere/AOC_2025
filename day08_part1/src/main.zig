const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const AutoHashmap = std.AutoHashMap;
const libaoc = @import("libaoc");
const std = @import("std");
const PriorityQueue = std.PriorityQueue;

pub const DebugArena = struct {
    debug_allocator: std.heap.DebugAllocator(.{}),
    arena_allocator: std.heap.ArenaAllocator,

    pub fn init(arena: *@This()) void {
        arena.debug_allocator = std.heap.DebugAllocator(.{}).init;
        arena.arena_allocator = std.heap.ArenaAllocator.init(arena.debug_allocator.allocator());
    }

    pub fn deinit(self: *@This()) std.heap.Check {
        self.arena_allocator.deinit();
        const check = self.debug_allocator.deinit();
        return check;
    }

    pub fn allocator(self: *@This()) Allocator {
        return self.arena_allocator.allocator();
    }
};

const Empty = struct {
    const init = Empty{};
};

const Vec3 = struct {
    x: f64,
    y: f64,
    z: f64,

    pub fn initF64(x: f64, y: f64, z: f64) Vec3 {
        const vec = Vec3{ .x = x, .y = y, .z = z };

        return vec;
    }

    pub fn distanceFrom(self: Vec3, other: Vec3) f64 {
        const powf = struct {
            fn powf(a: f64, b: f64) f64 {
                return std.math.pow(f64, a, b);
            }
        }.powf;

        const sqrt = std.math.sqrt;

        // https://www.cuemath.com/euclidean-distance-formula/
        // d = √[ (x2 – x1)2 + (y2 – y1)2]
        // d = sqrt((x2 - x1)**2 + (y2 - y1)**2 + (z2 - z1)**2;

        const out = sqrt( //
            powf(other.x - self.x, 2) +
                powf(other.y - self.y, 2) +
                powf(other.z - self.z, 2));
        return out;
    }
};

const Vec3PairHandle = struct {
    one: usize,
    two: usize,
};

fn appendCombinationsHandles(alloc: Allocator, coordinates: []const Vec3, handles: *ArrayList(Vec3PairHandle)) !void {
    var duplicates_map = AutoHashmap(Vec3PairHandle, Empty).init(alloc);
    defer duplicates_map.deinit();

    for (0..coordinates.len) |i| {
        for (0..coordinates.len) |j| {
            if (i == j) {
                continue;
            }

            const handle = Vec3PairHandle{ .one = i, .two = j };
            const handle_reveresed = Vec3PairHandle{ .one = handle.two, .two = handle.one };

            // ignore duplicates
            const is_duplicate = duplicates_map.contains(handle) or duplicates_map.contains(handle_reveresed);
            if (is_duplicate) {
                continue;
            }

            try duplicates_map.put(handle, Empty.init);
            try duplicates_map.put(handle_reveresed, Empty.init);
            try handles.append(alloc, handle);
        }
    }
}

fn sortHandlesByCoordinatePairDistances(coordinates: []const Vec3, handles: *ArrayList(Vec3PairHandle)) void {
    const HandlesSortingContext = struct {
        distances_ref: *ArrayList(Vec3PairHandle),
        coordinates_ref: []const Vec3,

        pub fn swap(self: *const @This(), cur1: usize, cur2: usize) void {
            const distances_ref = self.distances_ref;

            const left_handles = distances_ref.items[cur1];
            distances_ref.items[cur1] = distances_ref.items[cur2];
            distances_ref.items[cur2] = left_handles;
        }

        pub fn lessThan(self: *const @This(), cur1: usize, cur2: usize) bool {
            const coordinate_ref = self.coordinates_ref;
            const distances_ref = self.distances_ref;

            const left_handles = distances_ref.items[cur1];
            const right_handles = distances_ref.items[cur2];

            const left_distance = coordinate_ref[left_handles.one].distanceFrom(coordinate_ref[left_handles.two]);
            const right_distqance = coordinate_ref[right_handles.one].distanceFrom(coordinate_ref[right_handles.two]);

            return left_distance < right_distqance;
        }
    };

    const context = HandlesSortingContext{
        .distances_ref = handles,
        .coordinates_ref = coordinates,
    };
    std.sort.heapContext(0, handles.items.len, context);
}

fn appendCoordinates(alloc: Allocator, input: []u8, coordinates: *ArrayList(Vec3)) !void {
    const string_trimmed = std.mem.trim(u8, input, "\n\r ");
    var lines_iter = std.mem.splitScalar(u8, string_trimmed, '\n');
    while (lines_iter.next()) |line| {
        if (!libaoc.containsNonWhitespace(line)) {
            continue;
        }

        var part_iter = std.mem.splitScalar(u8, line, ',');

        var xyz: [3]f64 = undefined;
        for (0..xyz.len) |i| {
            const number_str = part_iter.next().?;
            xyz[i] = try std.fmt.parseFloat(f64, number_str);
        }

        const pos: Vec3 = Vec3.initF64(xyz[0], xyz[1], xyz[2]);
        try coordinates.append(alloc, pos);
    }
}

const UnionFind = struct {
    list: ArrayList(usize),

    fn init(alloc: Allocator, item_count: usize) !UnionFind {
        var items: ArrayList(usize) = .empty;
        for (0..item_count) |i| {
            try items.append(alloc, i);
        }

        return UnionFind{
            .list = items,
        };
    }

    fn deinit(self: *@This(), alloc: Allocator) void {
        self.list.deinit(alloc);
    }

    fn join(self: *@This(), pos1: usize, pos2: usize) void {
        const id1 = self.get_id(pos1).?;
        const id2 = self.get_id(pos2).?;

        self.list.items[id1] = id2;
    }

    fn get_id(self: *const @This(), item_pos: usize) ?usize {
        var cursor = item_pos;
        while (self.list.items[cursor] != cursor) {
            cursor = self.list.items[cursor];
        }

        return cursor;
    }

    fn count_non_empty_groups(self: *const @This()) usize {
        var count: usize = 0;

        for (0..self.list.items.len) |possible_id| {
            const is_id_used = (self.list.items[possible_id] == possible_id);
            if (is_id_used) {
                count += 1;
            }
        }

        return count;
    }

    const GroupIdIter = struct {
        pos: isize,
        uf: *const UnionFind,

        fn next(self: *GroupIdIter) ?usize {
            const limit = self.uf.list.items.len;
            const uf = self.uf;

            while (true) {
                self.pos += 1;
                if (self.pos >= limit) {
                    return null;
                }

                var member_iter = uf.group_member_iter(@intCast(self.pos));
                if (member_iter.next() == null) {
                    continue;
                }

                return @as(usize, @intCast(self.pos));
            }
        }
    };

    fn iter_group_ids(self: *const @This()) GroupIdIter {
        const iter = GroupIdIter{ .pos = -1, .uf = self };
        return iter;
    }

    const GroupMemberIter = struct {
        id: usize,
        pos: isize,
        uf: *const UnionFind,
        fn next(self: *GroupMemberIter) ?usize {
            const limit = self.uf.list.items.len;

            while (true) {
                self.pos += 1;
                if (@as(usize, @intCast(self.pos)) >= limit) {
                    return null;
                }

                if (self.uf.get_id(@intCast(self.pos)) == self.id) {
                    return @as(usize, @intCast(self.pos));
                }
            }
        }
    };

    fn group_member_iter(self: *const @This(), group_id: usize) GroupMemberIter {
        const iter = GroupMemberIter{
            .id = group_id,
            .pos = -1,
            .uf = self,
        };

        return iter;
    }
};

const Circuit = struct {
    id: usize,
    size: usize,
};
fn largest3Circuits(temp_alloc: Allocator, union_find: *const UnionFind) ![3]Circuit {
    var id_iter = union_find.iter_group_ids();

    const compare_func = struct {
        fn compare_func(context: Empty, left: Circuit, right: Circuit) std.math.Order {
            _ = context;
            if (right.size > left.size) {
                return .gt;
            } else if (right.size < left.size) {
                return .lt;
            } else if (right.size == left.size) {
                return .eq;
            }

            unreachable;
        }
    }.compare_func;

    var queue = PriorityQueue(Circuit, Empty, compare_func).init(temp_alloc, Empty.init);
    defer queue.deinit();

    var sizes = AutoHashmap(usize, Empty).init(temp_alloc);
    defer sizes.deinit();

    while (id_iter.next()) |circuit_id| {
        var member_iter = union_find.group_member_iter(circuit_id);
        var circuit_size: usize = 0;
        while (member_iter.next()) |_| {
            circuit_size += 1;
        }

        if (sizes.contains(circuit_size)) {
            continue;
        } else {
            try sizes.put(circuit_size, Empty.init);
        }

        const circuit = Circuit{
            .id = circuit_id,
            .size = circuit_size,
        };

        try queue.add(circuit);
    }
    const largest_circuits = [3]Circuit{ queue.remove(), queue.remove(), queue.remove() };

    return largest_circuits;
}

const StdoutWriter = struct {
    buffer: [1024]u8,
    stdout: std.fs.File,
    writer: std.fs.File.Writer,

    fn init(self: *@This()) void {
        @memset(self.buffer[0..], 0);
        self.stdout = std.fs.File.stdout();
        self.writer = self.stdout.writer(self.buffer[0..]);
    }

    fn deinit(self: *@This()) !void {
        return self.writer.interface.flush();
    }

    fn interface(self: *@This()) *std.io.Writer {
        return &self.writer.interface;
    }

    fn print(self: *@This(), comptime fmt: []const u8, args: anytype) !void {
        return self.writer.interface.print(fmt, args);
    }

    fn printFlushed(self: *@This(), comptime fmt: []const u8, args: anytype) !void {
        try self.writer.interface.print(fmt, args);
        try self.writer.interface.flush();
    }
};

fn joinClosest(n: usize, groups: *UnionFind, shortest_pair_handles: []const Vec3PairHandle) void {
    var cursor: usize = 0;

    for (0..n) |_| {
        const handle_to_closest_pair = shortest_pair_handles[cursor];
        cursor += 1;

        const left_handle = handle_to_closest_pair.one;
        const right_handle = handle_to_closest_pair.two;

        if (groups.get_id(left_handle) == groups.get_id(right_handle)) {
            continue;
        }

        groups.join(left_handle, right_handle);
    }
}

pub fn main() !void {
    libaoc.check_linkage();

    var debug_arena: DebugArena = undefined;
    debug_arena.init();
    const alloc = debug_arena.allocator();
    defer _ = debug_arena.deinit();

    var stdout: StdoutWriter = undefined;
    stdout.init();
    defer stdout.deinit() catch {};

    try stdout.printFlushed("Parsing coordinates\n", .{});
    const string = try libaoc.readFileToString(alloc, "input.txt");
    defer alloc.free(string);
    var coordinates = ArrayList(Vec3).empty;
    try appendCoordinates(alloc, string, &coordinates);

    std.mem.splitScalar(u8, string, 'T');

    try stdout.printFlushed("Iterating coordinates\n", .{});
    var handles_to_coordinates = ArrayList(Vec3PairHandle).empty;
    defer handles_to_coordinates.deinit(alloc);
    try appendCombinationsHandles(alloc, coordinates.items, &handles_to_coordinates);
    sortHandlesByCoordinatePairDistances(coordinates.items, &handles_to_coordinates);

    try stdout.printFlushed("Linking coordinates\n", .{});
    var union_find = try UnionFind.init(alloc, coordinates.items.len);
    defer union_find.deinit(alloc);
    joinClosest(1000, &union_find, handles_to_coordinates.items);

    try stdout.printFlushed("Finding largest\n", .{});
    const largest_circuits = try largest3Circuits(alloc, &union_find);
    const result = largest_circuits[0].size * largest_circuits[1].size * largest_circuits[2].size;
    try stdout.printFlushed("Result = {}\n", .{result});
}
