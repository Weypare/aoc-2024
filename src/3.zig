const std = @import("std");
const Allocator = std.mem.Allocator;

const DAY = 3;

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
    _ = alloc;

    var slice = input;
    var sum: u64 = 0;
    while (true) {
        const mul_idx = std.mem.indexOf(u8, slice, "mul") orelse break;
        slice = slice[mul_idx + 3 ..];
        if (slice.len == 0) break;

        if (slice[0] != '(') continue;
        slice = slice[1..];
        if (slice.len == 0) break;

        const comma_idx = std.mem.indexOf(u8, slice, ",") orelse break;
        if (comma_idx > 3) continue;
        const lhs = std.fmt.parseUnsigned(u64, slice[0..comma_idx], 10) catch continue;

        slice = slice[comma_idx + 1 ..];
        if (slice.len == 0) break;

        const parent_idx = std.mem.indexOf(u8, slice, ")") orelse break;
        if (parent_idx > 3) continue;
        const rhs = std.fmt.parseUnsigned(u64, slice[0..parent_idx], 10) catch continue;

        sum += lhs * rhs;
        slice = slice[parent_idx + 1 ..];
    }

    return sum;
}

fn part2(alloc: Allocator, input: []const u8) !?u64 {
    _ = alloc;

    var enabled = true;
    var slice = input;
    var sum: u64 = 0;
    while (true) {
        if (enabled) {
            const mul_idx = std.mem.indexOf(u8, slice, "mul") orelse break;
            const dont_idx = std.mem.indexOf(u8, slice, "don't()") orelse std.math.maxInt(usize);

            if (mul_idx < dont_idx) {
                // std.debug.print("processing mul\n", .{});
                slice = slice[mul_idx + 3 ..];
                if (slice.len == 0) break;

                if (slice[0] != '(') continue;
                slice = slice[1..];
                if (slice.len == 0) break;

                const comma_idx = std.mem.indexOf(u8, slice, ",") orelse break;
                if (comma_idx > 3) continue;
                const lhs = std.fmt.parseUnsigned(u64, slice[0..comma_idx], 10) catch continue;

                slice = slice[comma_idx + 1 ..];
                if (slice.len == 0) break;

                const parent_idx = std.mem.indexOf(u8, slice, ")") orelse break;
                if (parent_idx > 3) continue;
                const rhs = std.fmt.parseUnsigned(u64, slice[0..parent_idx], 10) catch continue;

                sum += lhs * rhs;
                slice = slice[parent_idx + 1 ..];
            } else {
                // std.debug.print("processing don't\n", .{});
                slice = slice[dont_idx + 6 ..];
                enabled = false;
            }
        } else {
            const do_idx = std.mem.indexOf(u8, slice, "do()") orelse break;
            // std.debug.print("processing do\n", .{});
            slice = slice[do_idx + 4 ..];
            enabled = true;
        }
    }

    return sum;
}
