const std = @import("std");
const Allocator = std.mem.Allocator;

const DAY = 1;

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
    var left = try std.ArrayList(u64).initCapacity(alloc, 1024);
    defer left.deinit();
    var right = try std.ArrayList(u64).initCapacity(alloc, 1024);
    defer right.deinit();
    var line_iter = std.mem.split(u8, input, "\n");

    while (line_iter.next()) |line| {
        if (line.len == 0) continue;
        const left_end = std.mem.indexOfScalar(u8, line, ' ').?;
        const left_n = std.fmt.parseUnsigned(u64, line[0..left_end], 10) catch unreachable;
        const right_start = 1 + std.mem.lastIndexOfScalar(u8, line, ' ').?;
        const right_n = std.fmt.parseUnsigned(u64, line[right_start..], 10) catch unreachable;
        try left.append(left_n);
        try right.append(right_n);
    }

    std.sort.pdq(u64, left.items, {}, std.sort.asc(u64));
    std.sort.pdq(u64, right.items, {}, std.sort.asc(u64));

    var sum: u64 = 0;
    for (left.items, right.items) |l, r| {
        sum += @max(l, r) - @min(l, r);
    }

    return sum;
}

fn part2(alloc: Allocator, input: []const u8) !?u64 {
    var left = try std.ArrayList(u64).initCapacity(alloc, 1024);
    defer left.deinit();
    var right = try std.ArrayList(u64).initCapacity(alloc, 1024);
    defer right.deinit();
    var line_iter = std.mem.split(u8, input, "\n");

    while (line_iter.next()) |line| {
        if (line.len == 0) continue;
        const left_end = std.mem.indexOfScalar(u8, line, ' ').?;
        const left_n = std.fmt.parseUnsigned(u64, line[0..left_end], 10) catch unreachable;
        const right_start = 1 + std.mem.lastIndexOfScalar(u8, line, ' ').?;
        const right_n = std.fmt.parseUnsigned(u64, line[right_start..], 10) catch unreachable;
        try left.append(left_n);
        try right.append(right_n);
    }

    std.sort.pdq(u64, left.items, {}, std.sort.asc(u64));
    std.sort.pdq(u64, right.items, {}, std.sort.asc(u64));

    var sum: u64 = 0;
    var offset: usize = 0;
    for (left.items) |l| {
        while (right.items[offset] < l) : (offset += 1) {}
        if (right.items[offset] > l) continue;
        var count: u64 = 0;
        while (offset + count < right.items.len and right.items[offset + count] == l) {
            count += 1;
        }
        sum += l * count;
    }

    return sum;
}
