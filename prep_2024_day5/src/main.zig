const std = @import("std");
const libaoc = @import("libaoc.zig");
const Allocator = std.mem.Allocator;

const PageNumber = i64;
/// Page Number before-> []PageNumber after
const RulesMap = std.AutoHashMap(PageNumber, std.ArrayList(PageNumber));

/// Page Number -> Index in array
const PagesMap = std.AutoHashMap(PageNumber, usize);

fn middle_page_number(line: []const u8) !PageNumber {
    var page_iter = std.mem.splitScalar(u8, line, ',');

    var count: usize = 0;
    while (page_iter.next()) |page| {
        if (libaoc.stringEmpty(page)) {
            continue;
        }
        count += 1;
    }

    const middle_pos = count / 2;
    page_iter = std.mem.splitScalar(u8, line, ',');
    var i: usize = 0;
    var number: i64 = -1;
    while (page_iter.next()) |page| {
        if (i == middle_pos) {
            number = try std.fmt.parseInt(i64, page, 10);
            break;
        }
        i += 1;
    }

    if (number == -1) {
        return error{LogicError}.LogicError;
    }

    return number;
}

fn pages_valid(alloc: Allocator, line: []const u8, rules: *RulesMap) !bool {
    var pages_map = PagesMap.init(alloc);
    defer pages_map.deinit();

    var page_iter = std.mem.splitScalar(u8, line, ',');
    var i: usize = 0;
    while (page_iter.next()) |page| {
        if (libaoc.stringEmpty(page)) {
            continue;
        }

        const page_int = try std.fmt.parseInt(PageNumber, page, 10);
        try pages_map.put(page_int, i);
        i += 1;
    }

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

fn print_rules(rules: *const RulesMap) void {
    var rules_iter = rules.iterator();
    while (rules_iter.next()) |rule| {
        for (rule.value_ptr.*.items) |rule_right| {
            std.debug.print("{}|{}\n", .{ rule.key_ptr.*, rule_right });
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
    var list = std.ArrayList([]u8).empty;
    defer {
        for (list.items) |item| {
            alloc.free(item);
        }
        list.deinit(alloc);
    }
    try libaoc.splitAlloc(alloc, &list, str, "\n\n");

    const rules = list.items[0];
    const pages_lines = list.items[1];

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
    while (pages_lines_iter.next()) |pages_line| {
        if (libaoc.stringEmpty(pages_line)) {
            continue;
        }
        const valid = try pages_valid(alloc, pages_line, &rules_map);
        if (valid) {
            tally += try middle_page_number(pages_line);
        }
    }

    try stdout.interface.print("Page numbers result: {}\n", .{tally});

    // std.debug.print("tally = {}\n", .{tally});
}
