const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const AutoHashmap = std.AutoHashMap;
const DebugArena = @import("debug_arena.zig").DebugArena;
const libaoc = @import("libaoc");
const std = @import("std");
const Tuple = std.meta.Tuple;
const PriorityQueue = std.PriorityQueue;

// const TaggedVec3 = struct {
//     vec: Vec3,
//     pool_id: ?usize,
//     pub fn initI64(x: i64, y: i64, z: i64) TaggedVec3 {
//         const t = TaggedVec3{
//             .vec = Vec3.initI64(x, y, z),
//             .pool_id = null,
//         };

//         return t;
//     }

//     fn vec3(self: TaggedVec3) Vec3 {
//         return self.vec;
//     }
// };

const Vec3 = struct {
    x: f64,
    y: f64,
    z: f64,

    pub fn initI64(x: i64, y: i64, z: i64) Vec3 {
        const vec = Vec3{ .x = @floatFromInt(x), .y = @floatFromInt(y), .z = @floatFromInt(z) };
        return vec;
    }

    pub fn debug(self: Vec3) void {
        std.debug.print("{:>8} {:>8} {:>8}\n", .{ self.x, self.y, self.z });
    }

    pub fn distanceFrom(self: Vec3, other: Vec3) f64 {
        const sqrt = std.math.sqrt;
        const pow = std.math.pow;

        // https://www.cuemath.com/euclidean-distance-formula/
        // d = √[ (x2 – x1)2 + (y2 – y1)2]
        // d = sqrt((x2 - x1)**2 + (y2 - y1)**2 + (z2 - z1)**2;

        const out = sqrt( //
            pow(f64, other.x - self.x, 2) +
                pow(f64, other.y - self.y, 2) +
                pow(f64, other.z - self.z, 2));
        return out;
    }

    pub fn eql(self: Vec3, other: Vec3) bool {
        return (self.x == other.x and self.y == other.y and self.z == other.z);
    }
};

const Coordinates = std.ArrayList(Vec3);
const Vec3PairHandle = struct {
    one: usize,
    two: usize,
    fn eql(left: Vec3PairHandle, right: Vec3PairHandle) bool {
        return left.one == right.one and left.two == right.two;
    }
};

fn appendCombinationsHandles(alloc: Allocator, coordinates: []const Vec3, distances: *ArrayList(Vec3PairHandle)) !void {
    var duplicates_map = AutoHashmap(Vec3PairHandle, bool).init(alloc);
    defer duplicates_map.deinit();

    // append all the items
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

            try duplicates_map.put(handle, true);
            try duplicates_map.put(handle_reveresed, true);
            try distances.append(alloc, handle);
        }
    }
}

fn sortHandlesByDistance(coordinates: []const Vec3, distances: *ArrayList(Vec3PairHandle)) void {
    const SortHandlesByDistancesContext = struct {
        distances_ref: *ArrayList(Vec3PairHandle),
        items_ref: []const Vec3,

        pub fn swap(self: *const @This(), cur1: usize, cur2: usize) void {
            const distances_ref = self.distances_ref;

            const left_handles = distances_ref.items[cur1];
            distances_ref.items[cur1] = distances_ref.items[cur2];
            distances_ref.items[cur2] = left_handles;
        }

        pub fn lessThan(self: *const @This(), cur1: usize, cur2: usize) bool {
            const items_ref = self.items_ref;
            const distances_ref = self.distances_ref;

            const left_handles = distances_ref.items[cur1];
            const right_handles = distances_ref.items[cur2];

            const left_distance = items_ref[left_handles.one].distanceFrom(items_ref[left_handles.two]);
            const right_distqance = items_ref[right_handles.one].distanceFrom(items_ref[right_handles.two]);

            return left_distance < right_distqance;
        }
    };

    const context = SortHandlesByDistancesContext{
        .distances_ref = distances,
        .items_ref = coordinates,
    };
    std.sort.heapContext(0, distances.items.len, context);
}

fn appendCoordinates(alloc: Allocator, input: []u8, coordinates: *ArrayList(Vec3)) !void {
    const string_trimmed = std.mem.trim(u8, input, "\n\r ");
    var lines_iter = std.mem.splitScalar(u8, string_trimmed, '\n');
    while (lines_iter.next()) |line| {
        if (!libaoc.containsNonWhitespace(line)) {
            continue;
        }

        var part_iter = std.mem.splitScalar(u8, line, ',');
        const x_str = part_iter.next().?;
        const y_str = part_iter.next().?;
        const z_str = part_iter.next().?;

        const x = try std.fmt.parseInt(i64, x_str, 10);
        const y = try std.fmt.parseInt(i64, y_str, 10);
        const z = try std.fmt.parseInt(i64, z_str, 10);

        const pos: Vec3 = Vec3.initI64(x, y, z);
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

    fn debugGroups(self: *const @This()) void {
        std.debug.print("Groups:\n", .{});
        for (0..self.list.items.len) |possible_id| {
            var ran_zero_times = true;
            for (0..self.list.items.len) |i| {
                const item_group_id = self.get_id(i).?;
                const is_in_group = item_group_id == possible_id;
                if (is_in_group and ran_zero_times) {
                    std.debug.print("  Group {:<3} contains: ", .{possible_id});
                    ran_zero_times = false;
                }

                if (is_in_group) {
                    std.debug.print("({:0>2}), ", .{
                        i,
                    });
                }
            }

            if (!ran_zero_times) {
                std.debug.print("\n", .{});
            }
        }
    }

    fn debugGroups2(self: *const @This(), vecs: []const Vec3) void {
        std.debug.print("Groups:\n", .{});
        for (0..self.list.items.len) |possible_id| {
            var ran_zero_times = true;
            for (0..self.list.items.len) |i| {
                const item_group_id = self.get_id(i).?;
                const is_in_group = item_group_id == possible_id;
                if (is_in_group and ran_zero_times) {
                    std.debug.print("  Group {:<3} contains:  ", .{possible_id});
                    ran_zero_times = false;
                }

                if (is_in_group) {
                    std.debug.print("{:>3} {:>3} {:>3}, {s:>3}", .{ vecs[i].x, vecs[i].y, vecs[i].z, "" });
                }
            }

            if (!ran_zero_times) {
                std.debug.print("\n", .{});
            }
        }
    }
};

const Circuit = struct {
    id: usize,
    size: usize,
};
fn largest3Circuits(alloc: Allocator, union_find: *const UnionFind) ![3]Circuit {
    // find largest circuit sizes

    var id_iter = union_find.iter_group_ids();
    const Empty = struct {
        fn init() @This() {
            return @This(){};
        }
    };

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

    var queue = PriorityQueue(Circuit, Empty, compare_func).init(alloc, Empty.init());
    var sizes = AutoHashmap(usize, Empty).init(alloc);

    while (id_iter.next()) |circuit_id| {
        var member_iter = union_find.group_member_iter(circuit_id);
        var circuit_size: usize = 0;
        while (member_iter.next()) |_| {
            circuit_size += 1;
        }

        std.debug.print("circuit {} has size {}\n", .{ circuit_id, circuit_size });
        if (sizes.contains(circuit_size)) {
            continue;
        } else {
            try sizes.put(circuit_size, Empty.init());
        }

        const circuit = Circuit{
            .id = circuit_id,
            .size = circuit_size,
        };

        try queue.add(circuit);
    }
    const largest_circuits = [3]Circuit{ queue.remove(), queue.remove(), queue.remove() };
    queue.deinit();
    sizes.deinit();

    return largest_circuits;
}

pub fn main() !void {
    libaoc.check_linkage();

    var debug_arena: DebugArena = undefined;
    debug_arena.init();
    const alloc = debug_arena.allocator();
    defer _ = debug_arena.deinit();

    // // stdout
    // var print_buffer = [1]u8{0} ** 1024;
    // const stdout_fd = std.fs.File.stdout();
    // var stdout = stdout_fd.writer(print_buffer[0..]);
    // defer stdout.interface.flush() catch {};

    const string = try libaoc.readFileToString(alloc, "input.txt");
    var coordinates = ArrayList(Vec3).empty;
    try appendCoordinates(alloc, string, &coordinates);

    var union_find = try UnionFind.init(alloc, coordinates.items.len);
    defer union_find.deinit(alloc);

    for (coordinates.items, 0..) |coord, i| {
        std.debug.print("coord {} is {} {} {}\n", .{ i, coord.x, coord.y, coord.z });
    }
    std.debug.print("\n", .{});

    var handles_to_coordinates = ArrayList(Vec3PairHandle).empty;
    defer handles_to_coordinates.deinit(alloc);
    try appendCombinationsHandles(alloc, coordinates.items, &handles_to_coordinates);
    sortHandlesByDistance(coordinates.items, &handles_to_coordinates);

    const max = 1000;
    var shortest_handles_cursor: usize = 0;
    for (0..max) |_| {
        const handle_to_closest_pair = handles_to_coordinates.items[shortest_handles_cursor];
        shortest_handles_cursor += 1;

        const left_handle = handle_to_closest_pair.one;
        const right_handle = handle_to_closest_pair.two;

        // skip already connected pairs
        if (union_find.get_id(left_handle) == union_find.get_id(right_handle)) {
            continue;
        }

        std.debug.print("Joining {any} to {any}", .{ left_handle, right_handle });
        union_find.join(left_handle, right_handle);
    }
    union_find.debugGroups();

    const largest_circuits = try largest3Circuits(alloc, &union_find);
    for (largest_circuits) |circuit| {
        std.debug.print("Circuit {any}\n", .{circuit});
    }

    const result = largest_circuits[0].size * largest_circuits[1].size * largest_circuits[2].size;

    std.debug.print("result {}\n", .{result});
}
