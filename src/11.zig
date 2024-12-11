const std = @import("std");
const Allocator = std.mem.Allocator;

const DAY = 11;

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
    var nums1 = try std.ArrayList(u64).initCapacity(alloc, 1024);
    defer nums1.deinit();
    var nums2 = try std.ArrayList(u64).initCapacity(alloc, 1024);
    defer nums2.deinit();

    const newline = std.mem.indexOfScalar(u8, input, '\n') orelse input.len;
    var num_iter = std.mem.splitScalar(u8, input[0..newline], ' ');
    while (num_iter.next()) |num| {
        const n = std.fmt.parseUnsigned(u64, num, 10) catch unreachable;
        nums1.appendAssumeCapacity(n);
    }

    const bufs = [2]*std.ArrayList(u64){ &nums1, &nums2 };
    var src_buf_idx: usize = 0;
    var remaining_iters: usize = 25;
    while (remaining_iters > 0) : ({
        src_buf_idx += 1;
        remaining_iters -= 1;
    }) {
        const src_buf = bufs[src_buf_idx % 2];
        var dst_buf = bufs[(src_buf_idx + 1) % 2];
        dst_buf.clearRetainingCapacity();
        for (src_buf.items) |num| {
            if (num == 0) {
                try dst_buf.append(1);
                continue;
            }
            const num_length = std.math.log10(num) + 1;
            if (num_length % 2 == 0) {
                const ten_power = std.math.pow(u64, 10, num_length / 2);
                const l = num / ten_power;
                const r = num % ten_power;
                try dst_buf.append(l);
                try dst_buf.append(r);
                continue;
            } else {
                try dst_buf.append(num * 2024);
                continue;
            }
            unreachable;
        }
    }

    return bufs[src_buf_idx % 2].items.len;
}

const BlinkCacheKey = struct { num: u64, remaining_blinks: u64 };

fn simulateBlinks(
    start: u64,
    remaining_blinks: usize,
    blink_cache: *std.AutoHashMap(BlinkCacheKey, u64),
) !u64 {
    if (remaining_blinks == 0) return 1;
    const key = BlinkCacheKey{ .num = start, .remaining_blinks = remaining_blinks };
    if (blink_cache.get(key)) |value| {
        return value;
    }

    if (start == 0) {
        const count = try simulateBlinks(1, remaining_blinks - 1, blink_cache);
        try blink_cache.put(key, count);
        return count;
    }

    const num_length = std.math.log10(start) + 1;
    if (num_length % 2 == 0) {
        const ten_power = std.math.pow(u64, 10, num_length / 2);
        const l = start / ten_power;
        const r = start % ten_power;
        const l_count = try simulateBlinks(l, remaining_blinks - 1, blink_cache);
        const r_count = try simulateBlinks(r, remaining_blinks - 1, blink_cache);
        const count = l_count + r_count;
        try blink_cache.put(key, count);
        return count;
    } else {
        const count = try simulateBlinks(start * 2024, remaining_blinks - 1, blink_cache);
        try blink_cache.put(key, count);
        return count;
    }
}

test "simulateBlinks" {
    var cache = std.AutoHashMap(BlinkCacheKey, u64).init(std.testing.allocator);
    defer cache.deinit();
    try std.testing.expectEqual(7, try simulateBlinks(125, 6, &cache));
    try std.testing.expectEqual(15, try simulateBlinks(17, 6, &cache));
}

fn part2(alloc: Allocator, input: []const u8) !?u64 {
    var nums = try std.ArrayList(u64).initCapacity(alloc, 1024);
    defer nums.deinit();

    const newline = std.mem.indexOfScalar(u8, input, '\n') orelse input.len;
    var num_iter = std.mem.splitScalar(u8, input[0..newline], ' ');
    while (num_iter.next()) |num| {
        const n = std.fmt.parseUnsigned(u64, num, 10) catch unreachable;
        nums.appendAssumeCapacity(n);
    }

    var blink_cache = std.AutoHashMap(BlinkCacheKey, u64).init(alloc);
    defer blink_cache.deinit();
    var sum: u64 = 0;
    for (nums.items) |num| {
        sum += try simulateBlinks(num, 75, &blink_cache);
    }

    return sum;
}
