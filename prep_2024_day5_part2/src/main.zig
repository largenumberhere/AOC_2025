const std = @import("std");
const libaoc = @import("libaoc.zig");
const Allocator = std.mem.Allocator;

const PageNumber = i64;

/// Page Number page_before -> []PageNumber page_after
const RulesMap = std.AutoHashMap(PageNumber, std.ArrayList(PageNumber));

/// Page Number -> Index in array
const PagesMap = std.AutoHashMap(PageNumber, usize);

fn pages_map_middle(map: *const PagesMap) i64 {
    const len = map.count();
    const middle_pos = len / 2;
    var map_iter = map.iterator();
    while (map_iter.next()) |item| {
        if (item.value_ptr.* == middle_pos) {
            return item.key_ptr.*;
        }
    }

    // A correctly formed PagesMap should always have a middle with value= count / 2
    unreachable;
}

fn pages_map_insert_line(alloc: Allocator, pages_map: *PagesMap, line: []const u8) !void {
    var page_iter = std.mem.splitScalar(u8, line, ',');
    var i: usize = 0;
    while (page_iter.next()) |page| {
        if (libaoc.stringEmpty(page)) {
            continue;
        }

        const page_int = try std.fmt.parseInt(PageNumber, page, 10);
        try pages_map.put(page_int, i);
        _ = alloc;
        i += 1;
    }
}

fn pages_map_clear(alloc: Allocator, pages_map: *PagesMap) void {
    _ = alloc; // unused, but implies allocation may happen in the map
    pages_map.clearRetainingCapacity();
}

fn pages_map_deinit(alloc: Allocator, pages_map: *PagesMap) void {
    _ = alloc; // unused, but implies allocation may happen in the map
    pages_map.clearAndFree();
}

fn pages_valid(pages_map: *PagesMap, rules: *const RulesMap) !bool {
    var rules_iter = rules.iterator();
    while (rules_iter.next()) |rule| {
        for (rule.value_ptr.items) |after| {
            const before = rule.key_ptr.*;

            if (pages_map.contains(before) and pages_map.contains(after)) {
                const before_pos = pages_map.get(before).?;
                const after_pos = pages_map.get(after).?;

                if (before_pos > after_pos) {
                    return false;
                }
            }
        }
    }

    return true;
}

fn pages_bubble_sort(pages_map: *PagesMap, rules: *const RulesMap) void {
    var rules_iter = rules.iterator();
    while (rules_iter.next()) |rule| {
        const before = rule.key_ptr.*;
        for (rule.value_ptr.*.items) |after| {
            if (pages_map.contains(before) and pages_map.contains(after)) {
                const before_pos = pages_map.get(before).?;
                const after_pos = pages_map.get(after).?;

                if (before_pos > after_pos) {
                    const before_pos_ptr = pages_map.getPtr(before).?;
                    const after_pos_ptr = pages_map.getPtr(after).?;

                    const old_before_pos = before_pos_ptr.*;
                    before_pos_ptr.* = after_pos_ptr.*;
                    after_pos_ptr.* = old_before_pos;
                }
            }
        }
    }
}

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();
    var stdout_handle = std.fs.File.stdout();
    var stdout_buffer = [1]u8{0} ** 128;
    var stdout = stdout_handle.writer(stdout_buffer[0..]);
    defer {
        stdout.interface.flush() catch {};
    }

    const str = try libaoc.readFileToString(alloc, "input.txt");
    defer alloc.free(str);
    var rules_and_pages = std.ArrayList([]u8).empty;
    defer {
        for (rules_and_pages.items) |item| {
            alloc.free(item);
        }
        rules_and_pages.deinit(alloc);
    }
    try libaoc.splitAlloc(alloc, &rules_and_pages, str, "\n\n");

    const rules = rules_and_pages.items[0];
    const pages_lines = rules_and_pages.items[1];

    var rules_map = RulesMap.init(alloc);
    defer {
        var iter = rules_map.iterator();
        while (iter.next()) |pair| {
            pair.value_ptr.deinit(alloc);
        }

        rules_map.deinit();
    }

    var rules_lines = std.mem.splitScalar(u8, rules, '\n');
    while (rules_lines.next()) |rule_line| {
        if (libaoc.containsNonWhitespace(rule_line)) {
            var pair_iter = std.mem.splitScalar(u8, rule_line, '|');
            const left = pair_iter.next().?;
            const right = pair_iter.next().?;

            std.debug.assert(pair_iter.next() == null);

            const left_int = try std.fmt.parseInt(i64, left, 10);
            const right_int = try std.fmt.parseInt(i64, right, 10);

            if (!rules_map.contains(left_int)) {
                try rules_map.put(left_int, std.ArrayList(i64).empty);
            }
            const list2 = rules_map.getPtr(left_int).?;
            try list2.*.append(alloc, right_int);
        }
    }

    var pages_lines_iter = std.mem.splitScalar(u8, pages_lines, '\n');
    var tally: i64 = 0;
    var pages_map = PagesMap.init(alloc);

    defer pages_map.deinit();
    while (pages_lines_iter.next()) |pages_line| {
        if (libaoc.stringEmpty(pages_line)) {
            continue;
        }

        pages_map_clear(alloc, &pages_map);
        try pages_map_insert_line(alloc, &pages_map, pages_line);

        const valid = try pages_valid(&pages_map, &rules_map);
        if (!valid) {
            while (!try pages_valid(&pages_map, &rules_map)) {
                pages_bubble_sort(&pages_map, &rules_map);
            }
            tally += pages_map_middle(&pages_map);
        }
    }

    try stdout.interface.print("Page numbers result: {}\n", .{tally});
}
