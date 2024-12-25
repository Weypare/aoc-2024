const std = @import("std");
const Allocator = std.mem.Allocator;

const DAY = 25;

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

const Array = struct {
    buf: []const u8,
    stride: usize,
    width: usize,
    height: usize,

    fn at(self: *const @This(), row: isize, col: isize) ?u8 {
        if (row < 0 or col < 0) return null;
        const r = @as(usize, @intCast(row));
        const c = @as(usize, @intCast(col));
        if (r >= self.height or c >= self.width) return null;
        const idx = r * self.stride + c;
        return self.buf[idx];
    }
};

const Lock = [5]u8;
const Key = [5]u8;

fn part1(alloc: Allocator, input: []const u8) !?u64 {
    var locks = std.ArrayList(Lock).init(alloc);
    defer locks.deinit();
    var keys = std.ArrayList(Key).init(alloc);
    defer keys.deinit();

    const HEIGHT = 7;

    var section_iter = std.mem.split(u8, input, "\n\n");
    while (section_iter.next()) |section| {
        if (section.len == 0) continue;
        const array = Array{ .buf = section, .stride = 6, .width = 5, .height = HEIGHT };
        if (array.at(0, 0).? == '#') {
            var lock: Lock = undefined;
            for (0..5) |col| {
                var count: u8 = 0;
                while (array.at(@intCast(count + 1), @intCast(col)) == '#') count += 1;
                lock[col] = count;
            }
            try locks.append(lock);
        } else {
            var key: Key = undefined;
            for (0..5) |col| {
                var count: u8 = 0;
                while (array.at(@intCast((array.height - 1) - count - 1), @intCast(col)) == '#') count += 1;
                key[col] = count;
            }
            try keys.append(key);
        }
    }

    var no_overlap: u64 = 0;
    for (locks.items) |lock| {
        keys_loop: for (keys.items) |key| {
            for (lock, key) |l, k| {
                if (l + k > HEIGHT - 2) continue :keys_loop;
            }
            no_overlap += 1;
        }
    }

    return no_overlap;
}

fn part2(alloc: Allocator, input: []const u8) !?u64 {
    _ = alloc;
    _ = input;
    return null;
}
