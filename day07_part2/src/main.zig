const std = @import("std");
const Allocator = std.mem.Allocator;
const libaoc = @import("libaoc");

const Vec2 = libaoc.Vec2;

fn linear_search(comptime T: type, slice: []const T, other: *const T) ?usize {
    for (slice, 0..) |*item, i| {
        if (item.* == other.*) {
            return i;
        }
    }

    return null;
}

// fn visit(lines: *std.ArrayList([]u8), pos: Vec2, tally: *usize) void {
//     const max = Vec2.initUsize(lines.items[0].len, lines.items.len);
//     const min = Vec2{ .x = 0, .y = 0 };

//     // base case
//     if (!pos.inRange(min, max)) {
//         return;
//     }

//     // single pipe case
//     if (lines.items[pos.yUsize()][pos.xUsize()] == '|' or lines.items[pos.yUsize()][pos.xUsize()] == 'S') {
//         std.debug.print("Visiting {any}\n", .{pos});
//         for (lines.items, 0..) |line, y| {
//             for (line, 0..) |chr, x| {
//                 if (pos.xUsize() == x and pos.yUsize() == y) {
//                     std.debug.print("x", .{});
//                 } else {
//                     std.debug.print("{c}", .{chr});
//                 }
//             }
//             std.debug.print("\n", .{});
//         }
//         std.debug.print("\n", .{});

//         const next = Vec2{ .x = pos.x, .y = pos.y + 1 };
//         visit(lines, next, tally);
//     }

//     // fork case
//     else if (lines.items[pos.yUsize()][pos.xUsize()] == '^') {
//         if (tally.* % 1000000 == 0) {
//             std.debug.print("depth = {}\n", .{tally.*});
//         }

//         const left = Vec2{ .x = pos.x - 1, .y = pos.y };
//         const right = Vec2{ .x = pos.x + 1, .y = pos.y };

//         tally.* += 1;

//         visit(lines, left, tally);
//         visit(lines, right, tally);
//     }

//     // end of recursion
// }

const Node = struct {
    children: std.ArrayList(?*Node) = std.ArrayList(?*Node).empty,
    is_root: bool = false,
    type: enum {
        LineOrS,
        Fork,
    },
    position: Vec2,
};

pub fn main() !void {
    const Errors = error{
        UnsupportedSymbol,
        UndefinedEdgeCase,
    };

    libaoc.check_linkage();

    // buffer allocator
    const kilobyte = 1024;
    var allocator_backing = [1]u8{0} ** (100 * kilobyte);
    var buffer_alloc = std.heap.FixedBufferAllocator.init(allocator_backing[0..]);
    const balloc = buffer_alloc.allocator();

    // stdout
    var print_buffer = [1]u8{0} ** 8192;
    const stdout_fd = std.fs.File.stdout();
    var stdout = stdout_fd.writer(print_buffer[0..]);
    defer stdout.interface.flush() catch {};

    var lines_list = std.ArrayList([]u8).empty;
    defer {
        for (lines_list.items) |line| {
            balloc.free(line);
        }
        lines_list.deinit(balloc);
    }

    try libaoc.readFileLinesToStrings(balloc, "input.txt", &lines_list);
    libaoc.trimLines(balloc, &lines_list);

    // nb: assumes flat 2d matrix, not a jagged array
    const lines = lines_list.items;
    var splits_tally: i64 = 0;
    for (0..lines.len) |i| {
        for (0..lines[0].len) |j| {
            if (lines[i][j] == 'S' or lines[i][j] == '|') {
                const can_look_down1 = (i < lines.len - 1);
                const down1 = i + 1;
                if (!can_look_down1) {
                    continue;
                } else if (lines[down1][j] == '|') {
                    continue;
                } else if (lines[down1][j] == '.') {
                    lines[down1][j] = '|';
                    continue;
                } else if (lines[down1][j] != '^') {
                    return Errors.UnsupportedSymbol;
                }

                const can_look_down2 = (i < lines.len - 2);
                if (!can_look_down2) {
                    return Errors.UndefinedEdgeCase;
                }

                const can_look_left = j >= 1;
                const can_look_right = j < lines[0].len - 1;
                const left = j - 1;
                const right = j + 1;

                if (can_look_left or can_look_right) {
                    splits_tally += 1;
                }

                if (can_look_left) {
                    lines[down1][left] = '|';
                }

                if (can_look_right) {
                    lines[down1][right] = '|';
                }
            }
        }
    }

    for (lines) |line| {
        try stdout.interface.print("{s}\n", .{line});
    }
    try stdout.interface.print("\n", .{});
    try stdout.interface.print("splits count = {}\n", .{splits_tally});
    try stdout.interface.flush();

    var node_arena = std.heap.ArenaAllocator.init(balloc);
    const nalloc = node_arena.allocator();

    const start_x = linear_search(u8, lines[0], &'S').?;

    const max = Vec2.initUsize(lines.items[0].len, lines.items.len);
    const min = Vec2{ .x = 0, .y = 0 };
    const root_pos = Vec2{ .x = start_x, .y = 0 };

    const root_node = (try nalloc.create(Node));
    root_node.* = Node{ .children = std.ArrayList(*Node).empty, .parent = null, .position = root_pos, .type = .LineOrS, .is_root = true };

    var pos = root_pos;
    var node = root_node;
    while (true) {
        const child1 = Vec2{ .x = pos.x - 1, .y = pos.y + 1 };
        const child2 = Vec2{ .x = pos.x + 0, .y = pos.y + 1 };
        const child3 = Vec2{ .x = pos.x - 1, .y = pos.y + 1 };

  

        if (child2.inRange(min, max) and lines[child2.yUsize()][child2.xUsize()] == '^') {


            if (child1.inRange(min, max) and lines[child1.yUsize()][child1.xUsize()] == '|') {
                const new_node = try nalloc.create(Node);
                new_node.* = Node{
                    .type = .LineOrS,
                    .position = child1
                };
                try node.children.append(nalloc, new_node);
            }
        

            if (child3.inRange(min, max) and lines[child3.yUsize()][child3.xUsize()] == '|') {

            }

        } else if (child2.inRange(min, max) and lines[child2.yUsize()][child2.xUsize()] == '|') {
            
            
        }

    }

    // for (lines) |line| {
    //     for (line) |chr| {
    //         // if a fork and the block above connects to the root, add the two nodes bellow
    //     }

    // var tally: usize = 1;
    // visit(&lines_list, Vec2.initUsize(s_pos, 0), &tally);
    // std.debug.print("tally ={}\n", .{tally});
}
