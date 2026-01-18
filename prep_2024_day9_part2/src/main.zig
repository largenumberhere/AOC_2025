// NB: This branch is not a working solution!

const std = @import("std");
const Allocator = std.mem.Allocator;
const libaoc = @import("zigaoc2025");

const BlockType = enum {
    file,
    gap,
};

const FreeSpace = struct { position: usize = 0, length: usize = 0 };

fn compareFreeSpace(_: void, left: FreeSpace, right: FreeSpace) std.math.Order {
    if (left.position > right.position) {
        return .gt;
    } else if (left.position < right.position) {
        return .lt;
    } else if (left.position == right.position) {
        return .eq;
    } else unreachable;
}

const FreeQueue = struct {
    const Self = @This();

    const FreeList = std.AutoHashMap(usize, usize);
    free_list: FreeList,

    pub fn init(alloc: Allocator) Self {
        const self = Self{ .free_list = FreeList.init(alloc) };
        return self;
    }

    pub fn deinit(
        self: *Self,
    ) void {
        self.free_list.deinit();
    }

    pub fn insert(self: *Self, position: usize, length: usize) !void {
        if (self.free_list.contains(position)) {
            if (self.free_list.get(position) != length) {
                unreachable;
            }
        } else {
            try self.free_list.put(position, length);
        }
    }

    pub fn move_forward(self: *Self, old_position: usize, length: usize, new_length: usize) void {
        const entry = self.free_list.getEntry(old_position).?;
        std.debug.assert(entry.value_ptr.* == length);
        entry.value_ptr.* = new_length;
        entry.key_ptr.* = old_position + (length - new_length);

        std.debug.assert(self.free_list.remove(old_position));
    }

    pub fn remove(self: *Self, position: usize, length: usize) void {
        std.debug.assert(self.free_list.get(position) == length);
        std.debug.assert(self.free_list.remove(position));
    }

    pub fn find_first(self: *Self, max_position: usize, min_length: usize) ?FreeSpace {
        var iter = self.free_list.iterator();
        var best: ?FreeSpace = null;
        while (iter.next()) |item| {
            const new_space = FreeSpace{ .length = item.value_ptr.*, .position = item.key_ptr.* };
            if (new_space.position >= max_position or new_space.length < min_length) {
                continue;
            }
            if (best) |b| {
                if (new_space.position < b.position) {
                    best = new_space;
                }
            } else {
                best = new_space;
            }
        }

        return best;
    }

    pub fn debug(self: *const Self) void {
        var iter = self.free_list.iterator();
        std.debug.print("{s} {s}", .{ @typeName(Self), "{\n" });
        while (iter.next()) |item| {
            std.debug.print("    {} : {}\n", .{ item.key_ptr.*, item.value_ptr.* });
        }
        std.debug.print("{s}", .{"}"});
    }
};

const Block = struct { id: ?u64, block_type: BlockType };

fn expand(alloc: Allocator, list: *std.ArrayList(Block), disk_map: []const u8) !void {
    var file_id: isize = -1;

    for (disk_map, 0..) |character, i| {
        const is_file = i % 2 == 0;
        if (is_file) {
            file_id += 1;
        }

        const arr = [1]u8{character};

        const int = try std.fmt.parseInt(u64, arr[0..], 10);

        var block: Block = undefined;

        for (0..int) |_| {
            if (is_file) {
                block = Block{
                    .id = @intCast(file_id),
                    .block_type = .file,
                };
            } else {
                block = Block{ .id = null, .block_type = .gap };
            }

            try list.append(alloc, block);
        }
    }
}

fn block_end(list: *const std.ArrayList(Block), block_index: usize) usize {
    const block = &list.items[block_index];
    var i = block_index;
    if (block.id) |id| {
        std.debug.assert(block.block_type == .file);
        while (i < list.items.len and list.items[i].id == id) : (i += 1) {}
    } else {
        std.debug.assert(block.block_type == .gap);
        while (i < list.items.len and list.items[i].block_type == .gap) : (i += 1) {}
    }

    return i;
}

fn block_start(list: *const std.ArrayList(Block), block_index: usize) usize {
    const block = &list.items[block_index];
    var i = block_index;
    if (block.id) |id| {
        std.debug.assert(block.block_type == .file);
        while (i >= 1 and list.items[i - 1].id == id) : (i -= 1) {}
    } else {
        std.debug.assert(block.block_type == .gap);
        while (i >= 1 and list.items[i - 1].block_type == .gap) : (i -= 1) {}
    }

    return i;
}

fn swap_slices(comptime T: type, left: []T, right: []T) !void {
    if (left.len != right.len) {
        return error{SliceLengthMismatch}.SliceLengthMismatch;
    }

    for (0..left.len) |i| {
        const tmp = left[i];
        left[i] = right[i];
        right[i] = tmp;
    }
}

fn defrag2(list: *std.ArrayList(Block), free_queue: *FreeQueue) !void {
    var i = list.items.len;
    while (i > 0) {
        i -= 1;
        const item = &list.items[i];
        if (item.block_type != .file) {
            continue;
        }

        const start = block_start(list, i);
        const end = block_end(list, i);
        const file_len = end - start;

        const best_free = free_queue.find_first(i, file_len) orelse continue;
        const gap_start = best_free.position;
        const gap_len = block_end(list, best_free.position) - block_start(list, best_free.position);

        if (gap_start > i) {
            continue;
        }

        const left = list.items[gap_start .. gap_start + file_len];
        const right = list.items[start..end];
        swap_slices(Block, left, right) catch @panic("invalid swap");

        if (gap_len == file_len) {
            free_queue.remove(best_free.position, best_free.length);
            debug_blocks(list.items);
            debug_frees(free_queue.*);
        } else {
            debug_blocks(list.items);
            debug_frees(free_queue.*);
            free_queue.move_forward(best_free.position, best_free.length, best_free.length - file_len);
        }

        i = start;
    }
}

fn checksum1(items: []const Block) u64 {
    var checksum: u64 = 0;
    for (items, 0..) |item, i| {
        if (item.block_type == .file) {
            const item_sum: u64 = @as(u64, @intCast(i)) * item.id.?;
            checksum += item_sum;
        }
    }

    return checksum;
}

fn debug_blocks(blocks: []const Block) void {
    for (blocks) |block| {
        switch (block.block_type) {
            .file => {
                if (block.id) |id| {
                    std.debug.print("{}", .{id});
                } else {
                    std.debug.print("?", .{});
                }
            },
            .gap => {
                std.debug.print(".", .{});
            },
        }
    }
    std.debug.print("\n", .{});
}

fn load_frees(free_list: *FreeQueue, disk_map: std.ArrayList(Block)) !void {
    var i: usize = 0;
    while (i < disk_map.items.len) {
        if (disk_map.items[i].block_type == .gap) {
            const start = block_start(&disk_map, i);
            const end = block_end(&disk_map, i);

            try free_list.insert(start, end - start);
            i += (end - start);
            continue;
        }

        i += 1;
    }
}

fn debug_frees(free_list: FreeQueue) void {
    free_list.debug();
}

// free list needs:
// - fast lookup size -> first block_pos
// - fast random removal
// - hashmap[min_size] pos  ?
// - hashmap[max_size] pos ?
// - linked list sorted by position(low to high) and ?

// - list of ?list of free[space], where index1 = size, index2 = position
// - shrink(size, position, newsize) function
// - insert(size, position) function

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

    const file_contents = try libaoc.readFileToString(alloc, "/home/rose/Documents/programming/aoc_2025/prep_2024_day9_part2/sample_input.txt");
    defer alloc.free(file_contents);
    const file = std.mem.trim(u8, file_contents, " \n\r\t");
    var list = std.ArrayList(Block).empty;
    defer list.deinit(alloc);

    var free_queue = FreeQueue.init(alloc);
    defer free_queue.deinit();

    try stdout.interface.print("Please wait. This one takes a minuite...\n", .{});
    try stdout.interface.flush();
    try expand(alloc, &list, file);
    try load_frees(&free_queue, list);
    debug_frees(free_queue);
    debug_blocks(list.items);
    try defrag2(&list, &free_queue);
    try stdout.interface.print("{}\n", .{checksum1(list.items)});
    debug_blocks(list.items);
    debug_frees(free_queue);
}
