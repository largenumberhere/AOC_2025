const std = @import("std");
const Allocator = std.mem.Allocator;
const libaoc = @import("zigaoc2025");

const BlockType = enum {
    file,
    gap,
};

const FreeSpace = struct { position: usize };

fn compareFreeSpace(_: void, left: FreeSpace, right: FreeSpace) std.math.Order {
    if (left.position > right.position) {
        return .gt;
    } else if (left.position < right.position) {
        return .lt;
    } else if (left.position == right.position) {
        return .eq;
    } else unreachable;
}

const FreeQueue = std.PriorityQueue(FreeSpace, void, compareFreeSpace);

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

fn find_first_free(block_size: usize, list: *const std.ArrayList(Block), free_queue: *FreeQueue) ?FreeSpace {
    var iter = free_queue.iterator();
    var best: ?FreeSpace = null;

    while (iter.next()) |item| {
        const best_pos = if (best) |b| b.position else std.math.maxInt(usize);
        const start = item.position;
        const end = block_end(list, item.position);
        const len = end - start;
        if (len >= block_size and item.position < best_pos) {
            best = item;
        }
    }

    if (best) |b| {
        std.debug.assert(list.items[b.position].block_type == .gap);
    }
    return best;
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
        const len = end - start;

        const best_free = find_first_free(len, list, free_queue) orelse continue;
        const gap_start = best_free.position;
        const gap_len = block_end(list, best_free.position) - block_start(list, best_free.position);

        if (gap_start > i) {
            continue;
        }

        const left = list.items[gap_start .. gap_start + len];
        const right = list.items[start..end];

        swap_slices(Block, left, right) catch @panic("invalid swap");

        if (gap_len == len) {
            var iter = free_queue.iterator();
            var j: usize = 0;
            var remove_pos: ?usize = null;
            while (iter.next()) |f| : (j += 1) {
                if (f.position == best_free.position) {
                    remove_pos = j;
                    break;
                }
            }

            _ = free_queue.removeIndex(remove_pos.?);
        } else {
            try free_queue.update(best_free, FreeSpace{ .position = best_free.position + len });
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

            try free_list.add(FreeSpace{ .position = start });

            i = end;
            continue;
        }

        i += 1;
    }
}

fn debug_frees(free_list: FreeQueue) void {
    std.debug.print("free list {}: ", .{free_list.count()});

    for (free_list.items) |item| {
        std.debug.print("[{}..]\n", .{item.position});
    }
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

    const file_contents = try libaoc.readFileToString(alloc, "sample_input.txt");
    defer alloc.free(file_contents);
    const file = std.mem.trim(u8, file_contents, " \n\r\t");
    var list = std.ArrayList(Block).empty;
    defer list.deinit(alloc);

    var free_queue = FreeQueue.init(alloc, {});
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
