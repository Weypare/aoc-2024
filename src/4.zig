const std = @import("std");
const Allocator = std.mem.Allocator;

const DAY = 4;

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

const Iter = struct {
    array: *const Array,
    dir_x: isize,
    dir_y: isize,
    cur_x: isize,
    cur_y: isize,

    fn next(self: *@This()) ?u8 {
        defer self.cur_x += self.dir_x;
        defer self.cur_y += self.dir_y;
        return self.array.at(self.cur_y, self.cur_x);
    }
};

fn part1(alloc: Allocator, input: []const u8) !?u64 {
    _ = alloc;
    const width = std.mem.indexOfScalar(u8, input, '\n').?;
    const stride = width + 1;
    var height: usize = 0;
    {
        var lines_iter = std.mem.splitScalar(u8, input, '\n');
        while (lines_iter.next()) |line| {
            if (line.len == 0) continue;
            height += 1;
        }
    }

    const array = Array{ .buf = input, .stride = stride, .width = width, .height = height };
    const directions = [_]struct { isize, isize }{
        .{ -1, -1 }, .{ -1, 0 }, .{ -1, 1 },
        .{ 0, -1 },  .{ 0, 0 },  .{ 0, 1 },
        .{ 1, -1 },  .{ 1, 0 },  .{ 1, 1 },
    };

    var count: u64 = 0;
    for (0..height) |row| {
        for (0..width) |col| {
            if (array.at(@intCast(row), @intCast(col)) != 'X') continue;
            for (directions) |dir| {
                var iter = Iter{ .array = &array, .dir_x = dir[0], .dir_y = dir[1], .cur_x = @intCast(col), .cur_y = @intCast(row) };
                var buf: [4]u8 = undefined;
                buf[0] = iter.next() orelse continue;
                buf[1] = iter.next() orelse continue;
                buf[2] = iter.next() orelse continue;
                buf[3] = iter.next() orelse continue;
                if (std.mem.eql(u8, &buf, "XMAS")) count += 1;
            }
        }
    }

    return count;
}

fn part2(alloc: Allocator, input: []const u8) !?u64 {
    _ = alloc;
    const width = std.mem.indexOfScalar(u8, input, '\n').?;
    const stride = width + 1;
    var height: usize = 0;
    {
        var lines_iter = std.mem.splitScalar(u8, input, '\n');
        while (lines_iter.next()) |line| {
            if (line.len == 0) continue;
            height += 1;
        }
    }

    const array = Array{ .buf = input, .stride = stride, .width = width, .height = height };

    var count: u64 = 0;
    for (0..height) |row| {
        for (0..width) |col| {
            if (array.at(@intCast(row), @intCast(col)) != 'A') continue;

            var buf: [3]u8 = undefined;

            var iter1 = Iter{ .array = &array, .dir_x = 1, .dir_y = 1, .cur_x = @as(isize, @intCast(col)) - 1, .cur_y = @as(isize, @intCast(row)) - 1 };
            buf[0] = iter1.next() orelse continue;
            buf[1] = iter1.next() orelse continue;
            buf[2] = iter1.next() orelse continue;
            if (!std.mem.eql(u8, &buf, "MAS") and !std.mem.eql(u8, &buf, "SAM")) continue;

            var iter2 = Iter{ .array = &array, .dir_x = 1, .dir_y = -1, .cur_x = @as(isize, @intCast(col)) - 1, .cur_y = @as(isize, @intCast(row)) + 1 };
            buf[0] = iter2.next() orelse continue;
            buf[1] = iter2.next() orelse continue;
            buf[2] = iter2.next() orelse continue;
            if (!std.mem.eql(u8, &buf, "MAS") and !std.mem.eql(u8, &buf, "SAM")) continue;

            count += 1;
        }
    }

    return count;
}
