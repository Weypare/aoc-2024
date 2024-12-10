const std = @import("std");
const Allocator = std.mem.Allocator;

const DAY = 10;

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

    fn at(self: *const @This(), row: isize, col: isize) ?*const u8 {
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
    fn move(self: @This(), dir: Direction) Position {
        return .{ .col = self.col + dir.dx, .row = self.row + dir.dy };
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

fn collectReachableTrailends(array: *const Array, start: Position, reachable_trailends: *std.AutoHashMap(Position, usize)) !void {
    const v = array.at(start.row, start.col) orelse unreachable;
    if (v.* == '9') {
        const get_or_put = try reachable_trailends.getOrPut(start);
        if (get_or_put.found_existing) {
            get_or_put.value_ptr.* += 1;
        } else {
            get_or_put.value_ptr.* = 1;
        }
        return;
    }

    const dirs = [_]Direction{
        .{ .dx = 0, .dy = 1 },
        .{ .dx = 1, .dy = 0 },
        .{ .dx = 0, .dy = -1 },
        .{ .dx = -1, .dy = 0 },
    };

    for (dirs) |dir| {
        const step = start.move(dir);
        if (array.at(step.row, step.col)) |step_v| {
            if (step_v.* == v.* + 1) try collectReachableTrailends(array, step, reachable_trailends);
        }
    }
}

fn part1(alloc: Allocator, input: []const u8) !?u64 {
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

    var sum: u64 = 0;
    for (0..height) |row| {
        for (0..width) |col| {
            const p = .{ .col = @as(isize, @intCast(col)), .row = @as(isize, @intCast(row)) };
            const v = array.at(p.row, p.col) orelse unreachable;
            if (v.* == '0') {
                var reachable_trailends = std.AutoHashMap(Position, usize).init(alloc);
                defer reachable_trailends.deinit();
                try collectReachableTrailends(&array, p, &reachable_trailends);
                sum += reachable_trailends.count();
            }
        }
    }

    return sum;
}

fn part2(alloc: Allocator, input: []const u8) !?u64 {
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

    var sum: u64 = 0;
    for (0..height) |row| {
        for (0..width) |col| {
            const p = .{ .col = @as(isize, @intCast(col)), .row = @as(isize, @intCast(row)) };
            const v = array.at(p.row, p.col) orelse unreachable;
            if (v.* == '0') {
                var reachable_trailends = std.AutoHashMap(Position, usize).init(alloc);
                defer reachable_trailends.deinit();
                try collectReachableTrailends(&array, p, &reachable_trailends);
                var value_iter = reachable_trailends.valueIterator();
                while (value_iter.next()) |value| sum += value.*;
            }
        }
    }

    return sum;
}
