const std = @import("std");
const Allocator = std.mem.Allocator;

const DAY = 19;

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

fn isDesignPossible(available_patterns: *const std.AutoHashMap(usize, std.ArrayList([]const u8)), design: []const u8, cache: *std.AutoHashMap(usize, bool)) !bool {
    if (design.len == 0) return true;
    if (cache.get(design.len)) |possible| return possible;

    var iter = available_patterns.iterator();
    while (iter.next()) |entry| {
        const len = entry.key_ptr.*;
        const patterns = entry.value_ptr;
        if (len > design.len) continue;
        const idx = std.sort.binarySearch([]const u8, design[0..len], patterns.*.items, {}, lexicographic_order);
        if (idx == null) continue;
        if (try isDesignPossible(available_patterns, design[len..], cache)) {
            try cache.put(design.len, true);
            return true;
        // } else {
        }
    }

    try cache.put(design.len, false);
    return false;
}

fn lexicographic_order(_: void, a: []const u8, b: []const u8) std.math.Order {
    var i: usize = 0;
    while (i < a.len and i < b.len) : (i += 1) {
        if (a[i] < b[i]) return std.math.Order.lt;
        if (a[i] > b[i]) return std.math.Order.gt;
    }
    return std.math.Order.eq;
}

fn lexicographic_less_than(_: void, a: []const u8, b: []const u8) bool {
    var i: usize = 0;
    while (i < a.len and i < b.len) : (i += 1) {
        if (a[i] < b[i]) return true;
        if (a[i] > b[i]) return false;
    }
    return a.len < b.len;
}

fn part1(alloc: Allocator, input: []const u8) !?u64 {
    const section_split = std.mem.indexOf(u8, input, "\n\n").?;

    const available_patterns_input = input[0..section_split];
    const desired_designs_input = input[section_split + 2 ..];

    var available_patterns = std.AutoHashMap(usize, std.ArrayList([]const u8)).init(alloc);
    defer available_patterns.deinit();
    defer {
        var value_iter = available_patterns.valueIterator();
        while (value_iter.next()) |value| value.deinit();
    }

    var available_patterns_iter = std.mem.split(u8, available_patterns_input, ", ");
    while (available_patterns_iter.next()) |ap| {
        const get_or_put = try available_patterns.getOrPut(ap.len);
        if (get_or_put.found_existing) {
            try get_or_put.value_ptr.append(ap);
        } else {
            get_or_put.value_ptr.* = try std.ArrayList([]const u8).initCapacity(alloc, 128);
            get_or_put.value_ptr.appendAssumeCapacity(ap);
        }
    }
    {
        var value_iter = available_patterns.valueIterator();
        while (value_iter.next()) |value| {
            std.sort.pdq([]const u8, value.items, {}, lexicographic_less_than);
        }
    }

    var desired_designs_iter = std.mem.splitScalar(u8, desired_designs_input, '\n');

    var cache = std.AutoHashMap(usize, bool).init(alloc);
    defer cache.deinit();

    var count: u64 = 0;
    var idx: usize = 0;
    while (desired_designs_iter.next()) |design| : (idx += 1) {
        cache.clearRetainingCapacity();
        if (design.len == 0) continue;
        if (try isDesignPossible(&available_patterns, design, &cache)) {
            count += 1;
        }
    }

    return count;
}

// "aaabb" {"aa", "a" "b", "bb"}
// aa a bb
// aa a b b
// a aa bb
// a aa b b
// a a a bb
// a a a b b
fn countRearangements(available_patterns: *const std.AutoHashMap(usize, std.ArrayList([]const u8)), design: []const u8, cache: *std.AutoHashMap(usize, ?usize)) !?usize {
    if (design.len == 0) return 0;
    if (cache.get(design.len)) |possible| return possible;

    var count: ?usize = null;
    var iter = available_patterns.iterator();
    while (iter.next()) |entry| {
        const len = entry.key_ptr.*;
        const patterns = entry.value_ptr;
        if (len > design.len) continue;
        const idx = std.sort.binarySearch([]const u8, design[0..len], patterns.*.items, {}, lexicographic_order);
        if (idx == null) continue;
        if (try countRearangements(available_patterns, design[len..], cache)) |c| {
            // c == 0 means that current pattern finalized the design so we need to count this as one of the possible
            // rearrangements
            count = (count orelse 0) + if (c == 0) 1 else c;
        }
    }

    try cache.put(design.len, count);
    return count;
}

fn part2(alloc: Allocator, input: []const u8) !?u64 {
    const section_split = std.mem.indexOf(u8, input, "\n\n").?;

    const available_patterns_input = input[0..section_split];
    const desired_designs_input = input[section_split + 2 ..];

    var available_patterns = std.AutoHashMap(usize, std.ArrayList([]const u8)).init(alloc);
    defer available_patterns.deinit();
    defer {
        var value_iter = available_patterns.valueIterator();
        while (value_iter.next()) |value| value.deinit();
    }

    var available_patterns_iter = std.mem.split(u8, available_patterns_input, ", ");
    while (available_patterns_iter.next()) |ap| {
        const get_or_put = try available_patterns.getOrPut(ap.len);
        if (get_or_put.found_existing) {
            try get_or_put.value_ptr.append(ap);
        } else {
            get_or_put.value_ptr.* = try std.ArrayList([]const u8).initCapacity(alloc, 128);
            get_or_put.value_ptr.appendAssumeCapacity(ap);
        }
    }
    {
        var value_iter = available_patterns.valueIterator();
        while (value_iter.next()) |value| {
            std.sort.pdq([]const u8, value.items, {}, lexicographic_less_than);
        }
    }

    var desired_designs_iter = std.mem.splitScalar(u8, desired_designs_input, '\n');

    var cache = std.AutoHashMap(usize, ?usize).init(alloc);
    defer cache.deinit();

    var sum: u64 = 0;
    while (desired_designs_iter.next()) |design| {
        cache.clearRetainingCapacity();
        if (design.len == 0) continue;
        if (try countRearangements(&available_patterns, design, &cache)) |count| sum += count;
    }

    return sum;
}
