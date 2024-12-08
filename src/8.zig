const std = @import("std");
const Allocator = std.mem.Allocator;

const DAY = 8;

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

    fn at(self: *@This(), row: isize, col: isize) ?*const u8 {
        if (row < 0 or col < 0) return null;
        const r = @as(usize, @intCast(row));
        const c = @as(usize, @intCast(col));
        if (r >= self.height or c >= self.width) return null;
        const idx = r * self.stride + c;
        return &self.buf[idx];
    }
};

const Position = struct {
    col: isize,
    row: isize,
    fn sub(self: @This(), other: @This()) Position {
        return .{ .col = self.col - other.col, .row = self.row - other.row };
    }
    fn add(self: @This(), other: @This()) Position {
        return .{ .col = self.col + other.col, .row = self.row + other.row };
    }
    fn neg(self: @This()) @This() {
        return .{ .col = -self.col, .row = -self.row };
    }
};
const Direction = struct { dx: isize, dy: isize };

const PositionIter = struct {
    dir: Direction,
    cur: Position,

    fn next(self: *@This()) Position {
        defer self.cur.col += self.dir.dx;
        defer self.cur.row += self.dir.dy;
        return .{ .col = self.cur.col, .row = self.cur.row };
    }
};

fn part1(alloc: Allocator, input: []const u8) !?u64 {
    var antenas_by_frequencies = std.AutoHashMap(u8, std.ArrayList(Position)).init(alloc);
    defer antenas_by_frequencies.deinit();
    defer {
        var value_iter = antenas_by_frequencies.valueIterator();
        while (value_iter.next()) |positions| positions.deinit();
    }

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

    var array = Array{ .buf = input, .stride = stride, .width = width, .height = height };

    for (0..height) |row| {
        for (0..width) |col| {
            const v = array.at(@intCast(row), @intCast(col)).?.*;
            if (std.ascii.isAlphanumeric(v)) {
                const get_or_put = try antenas_by_frequencies.getOrPut(v);
                if (get_or_put.found_existing) {
                    try get_or_put.value_ptr.append(.{ .col = @intCast(col), .row = @intCast(row) });
                } else {
                    get_or_put.value_ptr.* = try std.ArrayList(Position).initCapacity(alloc, 128);
                    get_or_put.value_ptr.appendAssumeCapacity(.{ .col = @intCast(col), .row = @intCast(row) });
                }
            }
        }
    }

    var antinode_positions = std.AutoHashMap(Position, void).init(alloc);
    defer antinode_positions.deinit();
    var value_iter = antenas_by_frequencies.valueIterator();
    while (value_iter.next()) |positions| {
        for (positions.items, 0..) |first_pos, first_pos_idx| {
            const rest = positions.items[first_pos_idx + 1 ..];
            for (rest) |second_pos| {
                const diff = second_pos.sub(first_pos);
                const antinode1_pos = first_pos.sub(diff);
                const antinode2_pos = second_pos.add(diff);
                if (array.at(antinode1_pos.row, antinode1_pos.col) != null) try antinode_positions.put(antinode1_pos, {});
                if (array.at(antinode2_pos.row, antinode2_pos.col) != null) try antinode_positions.put(antinode2_pos, {});
            }
        }
    }

    return antinode_positions.count();
}

fn part2(alloc: Allocator, input: []const u8) !?u64 {
    var antenas_by_frequencies = std.AutoHashMap(u8, std.ArrayList(Position)).init(alloc);
    defer antenas_by_frequencies.deinit();
    defer {
        var value_iter = antenas_by_frequencies.valueIterator();
        while (value_iter.next()) |positions| positions.deinit();
    }

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

    var array = Array{ .buf = input, .stride = stride, .width = width, .height = height };

    for (0..height) |row| {
        for (0..width) |col| {
            const v = array.at(@intCast(row), @intCast(col)).?.*;
            if (std.ascii.isAlphanumeric(v)) {
                const get_or_put = try antenas_by_frequencies.getOrPut(v);
                if (get_or_put.found_existing) {
                    try get_or_put.value_ptr.append(.{ .col = @intCast(col), .row = @intCast(row) });
                } else {
                    get_or_put.value_ptr.* = try std.ArrayList(Position).initCapacity(alloc, 128);
                    get_or_put.value_ptr.appendAssumeCapacity(.{ .col = @intCast(col), .row = @intCast(row) });
                }
            }
        }
    }

    var antinode_positions = std.AutoHashMap(Position, void).init(alloc);
    defer antinode_positions.deinit();
    var value_iter = antenas_by_frequencies.valueIterator();
    while (value_iter.next()) |positions| {
        for (positions.items, 0..) |first_pos, first_pos_idx| {
            try antinode_positions.put(first_pos, {});
            const rest = positions.items[first_pos_idx + 1 ..];
            for (rest) |second_pos| {
                const diff = second_pos.sub(first_pos);
                for ([2]Position{ diff, diff.neg() }) |dir| {
                    var pos_iter = PositionIter{
                        .dir = .{ .dx = dir.col, .dy = dir.row },
                        .cur = first_pos,
                    };
                    while (true) {
                        const pos = pos_iter.next();
                        if (array.at(pos.row, pos.col) == null) break else try antinode_positions.put(pos, {});
                    }
                }
            }
        }
    }

    return antinode_positions.count();
}
