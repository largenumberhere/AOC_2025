const std = @import("std");
const Allocator = std.mem.Allocator;
const libaoc = @import("libaoc");

const BlockType = enum {
    file,
    gap,
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

fn defrag1(list: *std.ArrayList(Block)) void {
    var left: usize = 0;
    var right = list.items.len - 1;
    while (left < list.items.len and right >= 0) : (left += 1) {
        if (list.items[left].block_type != .gap) {
            continue;
        }
        while (list.items[right].block_type != .file and right >= 0) : (right -= 1) {
            continue;
        }
        if (right == 0) {
            continue;
        }

        if (left > right) {
            continue;
        }
        list.items[left] = list.items[right];
        list.items[right].id = null;
        list.items[right].block_type = .gap;
    }
}

fn max_block_id(blocks: []const Block) u64 {
    var max: u64 = 0;
    for (blocks) |block| {
        if (block.id) |id| {
            if (id > max) {
                max = id;
            }
        }
    }

    return max;
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

    try expand(alloc, &list, file);
    defrag1(&list);
    std.debug.print("{}\n", .{checksum1(list.items)});
}
