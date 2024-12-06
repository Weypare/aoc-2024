const std = @import("std");
const Allocator = std.mem.Allocator;

const DAY = 2;

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
    var nums = try std.ArrayList(u64).initCapacity(alloc, 1024);
    defer nums.deinit();

    var count: u64 = 0;
    var line_iter = std.mem.split(u8, input, "\n");
    report_loop: while (line_iter.next()) |report| {
        if (report.len == 0) continue;
        nums.clearRetainingCapacity();
        var level_iter = std.mem.split(u8, report, " ");
        while (level_iter.next()) |level| {
            const l = std.fmt.parseUnsigned(u64, level, 10) catch unreachable;
            nums.append(l) catch unreachable;
        }
        if (std.sort.isSorted(u64, nums.items, {}, std.sort.asc(u64))) {
            var window_iter = std.mem.window(u64, nums.items, 2, 1);
            while (window_iter.next()) |window| {
                const diff = window[1] - window[0];
                if (diff == 0 or diff > 3) continue :report_loop;
            }
            count += 1;
        } else if (std.sort.isSorted(u64, nums.items, {}, std.sort.desc(u64))) {
            var window_iter = std.mem.window(u64, nums.items, 2, 1);
            while (window_iter.next()) |window| {
                const diff = window[0] - window[1];
                if (diff == 0 or diff > 3) continue :report_loop;
            }
            count += 1;
        }
    }

    return count;
}

fn firstUnsorted(items: []const u64, lessThan: *const fn (lhs: u64, rhs: u64) bool) ?usize {
    var i: usize = 1;
    while (i < items.len) : (i += 1) {
        if (!lessThan(items[i - 1], items[i])) {
            return i - 1;
        }
    }
    return null;
}

pub fn isSortedStrict(
    items: []const u64,
    lessThan: *const fn (lhs: u64, rhs: u64) bool,
) bool {
    return firstUnsorted(items, lessThan) == null;
}

fn part2(alloc: Allocator, input: []const u8) !?u64 {
    var nums = try std.ArrayList(u64).initCapacity(alloc, 1024);
    defer nums.deinit();
    var other_nums = try std.ArrayList(u64).initCapacity(alloc, 1024);
    defer other_nums.deinit();

    var count: u64 = 0;
    var line_iter = std.mem.splitScalar(u8, input, '\n');
    while (line_iter.next()) |report| {
        if (report.len == 0) continue;
        nums.clearRetainingCapacity();
        var level_iter = std.mem.splitScalar(u8, report, ' ');
        while (level_iter.next()) |level| {
            const l = std.fmt.parseUnsigned(u64, level, 10) catch unreachable;
            nums.append(l) catch unreachable;
        }

        const AscSorted = struct {
            fn lessThan(lhs: u64, rhs: u64) bool {
                const diff = rhs -| lhs;
                return diff >= 1 and diff <= 3;
            }
        };
        const DescSorted = struct {
            fn lessThan(lhs: u64, rhs: u64) bool {
                const diff = lhs -| rhs;
                return diff >= 1 and diff <= 3;
            }
        };

        const funcs: [2]*const fn (lhs: u64, rhs: u64) bool = .{ AscSorted.lessThan, DescSorted.lessThan };
        for (funcs) |lessThan| {
            if (isSortedStrict(nums.items, lessThan)) {
                count += 1;
                break;
            }
            const offset = firstUnsorted(nums.items, lessThan).?;
            other_nums.clearRetainingCapacity();
            try other_nums.appendSlice(nums.items[0..offset]);
            try other_nums.appendSlice(nums.items[offset + 1 ..]);
            if (isSortedStrict(other_nums.items, lessThan)) {
                count += 1;
                break;
            }
            other_nums.clearRetainingCapacity();
            other_nums.appendSliceAssumeCapacity(nums.items[0 .. offset + 1]);
            other_nums.appendSliceAssumeCapacity(nums.items[offset + 2 ..]);
            if (isSortedStrict(other_nums.items, lessThan)) {
                count += 1;
                break;
            }
        }
    }

    return count;
}
