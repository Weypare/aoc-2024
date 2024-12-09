const std = @import("std");
const Allocator = std.mem.Allocator;

const DAY = 9;

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

const FREE_BLOCK = -1;

fn part1(alloc: Allocator, input: []const u8) !?u64 {
    var capacity: usize = 0;
    for (input) |c| {
        if (!std.ascii.isDigit(c)) continue;
        capacity += @intCast(c - '0');
    }
    var memory = try alloc.alloc(i64, capacity);
    defer alloc.free(memory);
    {
        var slice = memory[0..];
        var file_id: usize = 0;
        while (file_id * 2 < input.len) : (file_id += 1) {
            const i = file_id * 2;
            if (!std.ascii.isDigit(input[i])) continue;
            const n = input[i] - '0';
            @memset(slice[0..n], @intCast(file_id));
            slice = slice[n..];
            if (i + 1 >= input.len) continue;
            if (std.ascii.isDigit(input[i + 1])) {
                const n2 = input[i + 1] - '0';
                @memset(slice[0..n2], FREE_BLOCK);
                slice = slice[n2..];
            }
        }
    }

    {
        var slice = memory;
        while (slice.len > 0) {
            const non_free_idx = std.mem.lastIndexOfNone(i64, slice, &.{FREE_BLOCK}) orelse break;
            const free_space_idx = std.mem.indexOfScalar(i64, slice, FREE_BLOCK) orelse break;
            if (non_free_idx < free_space_idx) break;
            slice[free_space_idx] = slice[non_free_idx];
            slice[non_free_idx] = FREE_BLOCK;
            slice = slice[free_space_idx + 1 .. non_free_idx];
        }
    }

    var checksum: u64 = 0;
    for (memory, 0..) |n, i| {
        if (n == FREE_BLOCK) continue;
        checksum += @as(u64, @intCast(n)) * i;
    }

    return checksum;
}

fn part2(alloc: Allocator, input: []const u8) !?u64 {
    var capacity: usize = 0;
    for (input) |c| {
        if (!std.ascii.isDigit(c)) continue;
        capacity += @intCast(c - '0');
    }
    var memory = try alloc.alloc(i64, capacity);
    defer alloc.free(memory);
    {
        var slice = memory[0..];
        var file_id: usize = 0;
        while (file_id * 2 < input.len) : (file_id += 1) {
            const i = file_id * 2;
            if (!std.ascii.isDigit(input[i])) continue;
            const n = input[i] - '0';
            @memset(slice[0..n], @intCast(file_id));
            slice = slice[n..];
            if (i + 1 >= input.len) continue;
            if (std.ascii.isDigit(input[i + 1])) {
                const n2 = input[i + 1] - '0';
                @memset(slice[0..n2], FREE_BLOCK);
                slice = slice[n2..];
            }
        }
    }

    {
        var moved_file_set = std.AutoHashMap(i64, void).init(alloc);
        defer moved_file_set.deinit();
        var slice = memory;
        while (slice.len > 0) {
            while (slice[slice.len - 1] == FREE_BLOCK) slice = slice[0 .. slice.len - 1];

            const file_id = slice[slice.len - 1];
            const file_size = input[@as(usize, @intCast(file_id)) * 2] - '0';
            if (moved_file_set.contains(file_id)) {
                slice = slice[0 .. slice.len - file_size];
                continue;
            }

            var maybe_free_space_idx: ?usize = null;
            {
                var offset: usize = 0;
                var s = slice[0 .. slice.len - file_size];
                while (s.len > 0) {
                    const idx = std.mem.indexOfScalar(i64, s, FREE_BLOCK) orelse break;
                    var size: usize = 0;
                    while (idx + size < s.len and s[idx + size] == FREE_BLOCK) size += 1;
                    if (size >= file_size) {
                        maybe_free_space_idx = offset + idx;
                        break;
                    } else {
                        offset += idx + size;
                        s = s[idx + size ..];
                    }
                }
            }

            const free_space_idx = maybe_free_space_idx orelse {
                slice = slice[0 .. slice.len - file_size];
                continue;
            };

            // clear file at the end of fs
            @memset(slice[slice.len - file_size..], FREE_BLOCK);
            // set file in the free spot
            @memset(slice[free_space_idx..][0..file_size], file_id);

            slice = slice[0 .. slice.len - file_size];
            try moved_file_set.put(file_id, {});
        }
    }

    var checksum: u64 = 0;
    for (memory, 0..) |n, i| {
        if (n == FREE_BLOCK) continue;
        checksum += @as(u64, @intCast(n)) * i;
    }

    return checksum;
}
