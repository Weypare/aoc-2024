const std = @import("std");
const Allocator = std.mem.Allocator;

const DAY = 5;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    inline for (.{ "input/{d}.example.txt", "input/{d}.txt" }) |path| {
        blk: {
            var file_path_buf: [64]u8 = undefined;
            const file_path = std.fmt.bufPrint(&file_path_buf, path, .{DAY}) catch unreachable;
            const input = std.fs.cwd().readFileAlloc(alloc, file_path, std.math.maxInt(usize)) catch |e| switch (e) {
                error.FileNotFound => {
                    break :blk;
                },
                else => {
                    std.debug.print("{}", .{e});
                    return e;
                },
            };
            defer alloc.free(input);
            if (try part1(alloc, input)) |x| std.debug.print("{s:20} part 1: {d}\n", .{ file_path, x });
            if (try part2(alloc, input)) |x| std.debug.print("{s:20} part 2: {d}\n", .{ file_path, x });
        }
    }
}

fn part1(alloc: Allocator, input: []const u8) !?u64 {
    var constraints = std.AutoHashMap(u64, std.ArrayList(u64)).init(alloc);
    defer constraints.deinit();
    defer {
        var value_iter = constraints.valueIterator();
        while (value_iter.next()) |v| v.deinit();
    }

    var line_iter = std.mem.splitScalar(u8, input, '\n');
    while (line_iter.next()) |line| {
        if (line.len == 0) break;
        const bar = std.mem.indexOfScalar(u8, line, '|').?;
        const lhs = std.fmt.parseInt(u64, line[0..bar], 10) catch unreachable;
        const rhs = std.fmt.parseInt(u64, line[bar + 1 ..], 10) catch unreachable;
        const get_or_put = try constraints.getOrPut(lhs);
        if (!get_or_put.found_existing) {
            get_or_put.value_ptr.* = std.ArrayList(u64).init(alloc);
        }
        try get_or_put.value_ptr.append(rhs);
    }

    var sum: u64 = 0;
    var nums = try std.ArrayList(u64).initCapacity(alloc, 128);
    defer nums.deinit();
    process_update_loop: while (line_iter.next()) |line| {
        if (line.len == 0) break;
        nums.clearRetainingCapacity();
        var page_iter = std.mem.splitScalar(u8, line, ',');
        while (page_iter.next()) |page| {
            const p = std.fmt.parseInt(u64, page, 10) catch unreachable;
            try nums.append(p);
        }

        for (nums.items, 0..) |num, idx| {
            const c = constraints.get(num) orelse continue;
            for (nums.items[0..idx]) |before| {
                if (std.mem.indexOfScalar(u64, c.items, before) != null) {
                    continue :process_update_loop;
                }
            }
        }

        std.debug.assert(nums.items.len % 2 == 1);
        sum += nums.items[nums.items.len / 2];
    }

    return sum;
}

fn part2(alloc: Allocator, input: []const u8) !?u64 {
    var constraints = std.AutoHashMap(u64, std.ArrayList(u64)).init(alloc);
    defer constraints.deinit();
    defer {
        var value_iter = constraints.valueIterator();
        while (value_iter.next()) |v| v.deinit();
    }

    var line_iter = std.mem.splitScalar(u8, input, '\n');
    while (line_iter.next()) |line| {
        if (line.len == 0) break;
        const bar = std.mem.indexOfScalar(u8, line, '|').?;
        const lhs = std.fmt.parseInt(u64, line[0..bar], 10) catch unreachable;
        const rhs = std.fmt.parseInt(u64, line[bar + 1 ..], 10) catch unreachable;
        const get_or_put = try constraints.getOrPut(lhs);
        if (!get_or_put.found_existing) {
            get_or_put.value_ptr.* = std.ArrayList(u64).init(alloc);
        }
        try get_or_put.value_ptr.append(rhs);
    }

    var sum: u64 = 0;
    var nums = try std.ArrayList(u64).initCapacity(alloc, 128);
    defer nums.deinit();
    while (line_iter.next()) |line| {
        if (line.len == 0) break;
        nums.clearRetainingCapacity();
        var page_iter = std.mem.splitScalar(u8, line, ',');
        while (page_iter.next()) |page| {
            const p = std.fmt.parseInt(u64, page, 10) catch unreachable;
            try nums.append(p);
        }

        var correct = true;
        check_update_loop: for (nums.items, 0..) |num, idx| {
            const c = constraints.get(num) orelse continue;
            for (nums.items[0..idx]) |before| {
                if (std.mem.indexOfScalar(u64, c.items, before) != null) {
                    correct = false;
                    break :check_update_loop;
                }
            }
        }
        if (correct) continue;

        // NOTE: in general case this can be solved via a topological sort, which can produce multiple solutions. But
        // considering the fact that AoC is constructed in a way to only accept 1 answer, the inputs must be set up so
        // that only one topological sort exists. Therefore, it's possible to only look for an page which is ordered
        // exactly before the second half of the pages.
        const target_constraint_count = nums.items.len / 2;
        for (nums.items) |num| {
            const c = constraints.get(num) orelse continue;
            var count: usize = 0;
            for (nums.items) |other| {
                if (std.mem.indexOfScalar(u64, c.items, other) != null) {
                    count += 1;
                }
            }
            if (count == target_constraint_count) {
                sum += num;
                break;
            }
        }
    }

    return sum;
}
