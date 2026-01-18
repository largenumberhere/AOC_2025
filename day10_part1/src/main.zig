const std = @import("std");
const Allocator = std.mem.Allocator;
const libaoc = @import("libaoc");

const ButtonId = u8;
const Machine = struct {
    light_states: std.ArrayList(bool),
    button_toggle_lists: std.ArrayList(std.ArrayList(ButtonId)),

    fn deinit(self: *Machine, alloc: Allocator) void {
        for (self.button_toggle_lists.items) |*list| {
            list.deinit(alloc);
        }

        self.button_toggle_lists.deinit(alloc);
        self.light_states.deinit(alloc);
    }
};

fn debug_machine(machine: Machine) void {
    std.debug.print("Machine\t", .{});
    std.debug.print("\t[", .{});
    for (machine.light_states.items) |light| {
        if (light) {
            std.debug.print("#", .{});
        } else {
            std.debug.print(".", .{});
        }
    }
    std.debug.print("]", .{});

    for (machine.button_toggle_lists.items) |button_list| {
        std.debug.print("\t({any}), ", .{button_list.items});
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

    // try stdout.interface.print("Hello, world\n", .{});

    var strings = std.ArrayList([]u8).empty;
    defer {
        for (strings.items) |item| {
            alloc.free(item);
        }

        strings.deinit(alloc);
    }

    try libaoc.readFileLinesToStrings(alloc, "/home/rose/Documents/programming/aoc_2025/day10_part1/sample_input.txt", &strings);
    libaoc.trimLines(alloc, &strings);

    var machines = std.ArrayList(Machine).empty;
    defer {
        for (machines.items) |*m| {
            m.deinit(alloc);
        }

        machines.deinit(alloc);
    }

    for (strings.items) |item| {
        var line_iter = std.mem.splitScalar(u8, item, ' ');
        var machine = Machine{
            .button_toggle_lists = .empty,
            .light_states = .empty,
        };

        while (line_iter.next()) |segment| {
            if (segment.len < 1) {
                continue;
            }

            if (segment[0] == '[') {
                const start = 1;
                const end = std.mem.indexOfPosLinear(u8, segment, 1, "]").?;
                var cur: usize = start;
                while (cur < end) : (cur += 1) {
                    const state = if (segment[cur] == '.') false else if (segment[cur] == '#') true else null;
                    try machine.light_states.append(alloc, state.?);
                }
            } else if (segment[0] == '(') {
                const start = 1;
                const end = std.mem.indexOfPosLinear(u8, segment, 1, ")").?;
                var cur: usize = start;
                var light_list = std.ArrayList(ButtonId).empty;
                while (cur < end) : (cur += 1) {
                    if (segment[cur] == ',') {
                        continue;
                    }

                    const val = try std.fmt.parseInt(ButtonId, segment[cur .. cur + 1], 10);
                    try light_list.append(alloc, val);
                }

                try machine.button_toggle_lists.append(alloc, light_list);
            } else if (segment[0] == '{') {
                // joltage
            }
        }

        try machines.append(alloc, machine);
    }

    for (machines.items) |m| {
        debug_machine(m);
    }
}

// [#.]
// (\[[.#]+\])
// (,)
// \((\d,?)+\)
// {,}
// \{(\d,?)+\
