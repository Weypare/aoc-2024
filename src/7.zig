const std = @import("std");
const Allocator = std.mem.Allocator;

const DAY = 7;

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

fn backtrack1(target: u64, lhs: u64, rest: []const u64) bool {
    if (lhs > target) return false;
    if (rest.len == 0) return target == lhs;
    if (backtrack1(target, lhs + rest[0], rest[1..])) return true;
    if (backtrack1(target, lhs * rest[0], rest[1..])) return true;
    return false;
}

fn part1(alloc: Allocator, input: []const u8) !?u64 {
    var nums = try std.ArrayList(u64).initCapacity(alloc, 128);
    defer nums.deinit();

    var line_iter = std.mem.splitScalar(u8, input, '\n');

    var sum: u64 = 0;
    while (line_iter.next()) |line| {
        if (line.len == 0) continue;
        nums.clearRetainingCapacity();

        const colon_idx = std.mem.indexOfScalar(u8, line, ':') orelse unreachable;
        const target = std.fmt.parseInt(u64, line[0..colon_idx], 10) catch unreachable;

        var operand_iter = std.mem.splitScalar(u8, line[colon_idx + 2 ..], ' ');
        while (operand_iter.next()) |operand| {
            const o = std.fmt.parseInt(u64, operand, 10) catch unreachable;
            try nums.append(o);
        }

        if (backtrack1(target, nums.items[0], nums.items[1..])) sum += target;
    }

    return sum;
}

fn backtrack2(target: u64, lhs: u64, rest: []const u64) bool {
    if (lhs > target) return false;
    if (rest.len == 0) return target == lhs;
    if (backtrack2(target, lhs + rest[0], rest[1..])) return true;
    if (backtrack2(target, lhs * rest[0], rest[1..])) return true;
    const ten_power = std.math.powi(u64, 10, std.math.log10(rest[0]) + 1) catch unreachable;
    const concat = lhs * ten_power + rest[0];
    if (backtrack2(target, concat, rest[1..])) return true;
    return false;
}

fn part2(alloc: Allocator, input: []const u8) !?u64 {
    var nums = try std.ArrayList(u64).initCapacity(alloc, 128);
    defer nums.deinit();

    var line_iter = std.mem.splitScalar(u8, input, '\n');

    var sum: u64 = 0;
    while (line_iter.next()) |line| {
        if (line.len == 0) continue;
        nums.clearRetainingCapacity();

        const colon_idx = std.mem.indexOfScalar(u8, line, ':') orelse unreachable;
        const target = std.fmt.parseInt(u64, line[0..colon_idx], 10) catch unreachable;

        var operand_iter = std.mem.splitScalar(u8, line[colon_idx + 2 ..], ' ');
        while (operand_iter.next()) |operand| {
            const o = std.fmt.parseInt(u64, operand, 10) catch unreachable;
            try nums.append(o);
        }

        if (backtrack2(target, nums.items[0], nums.items[1..])) sum += target;
    }

    return sum;
}
