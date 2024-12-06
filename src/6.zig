const std = @import("std");
const Allocator = std.mem.Allocator;

const DAY = 6;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    inline for (.{ "input/{d}.example.txt", "input/{d}.txt" }) |path| {
        blk: {
            var file_path_buf: [64]u8 = undefined;
            const file_path = std.fmt.bufPrint(&file_path_buf, path, .{DAY}) catch unreachable;
            {
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
            }
            {
                const input = std.fs.cwd().readFileAlloc(alloc, file_path, std.math.maxInt(usize)) catch unreachable;
                defer alloc.free(input);
                if (try part2(alloc, input)) |x| std.debug.print("{s:20} part 2: {d}\n", .{ file_path, x });
            }
        }
    }
}

const Array = struct {
    buf: []u8,
    stride: usize,
    width: usize,
    height: usize,

    fn at(self: *@This(), row: isize, col: isize) ?*u8 {
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
    fn eq(self: @This(), other: @This()) bool {
        return self.col == other.col and self.row == other.row;
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

fn part1(alloc: Allocator, input: []u8) !?u64 {
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

    var array = Array{ .buf = input, .stride = stride, .width = width, .height = height };
    const dirs = [_]Direction{ .{ .dx = 0, .dy = -1 }, .{ .dx = 1, .dy = 0 }, .{ .dx = 0, .dy = 1 }, .{ .dx = -1, .dy = 0 } };

    var dir: usize = undefined;
    var guard_pos: Position = undefined;

    find_guard: for (0..height) |row| {
        for (0..width) |col| {
            const v = array.at(@intCast(row), @intCast(col)).?;
            guard_pos = .{ .col = @intCast(col), .row = @intCast(row) };
            switch (v.*) {
                '^' => {
                    dir = 0;
                    break :find_guard;
                },
                '>' => {
                    dir = 1;
                    break :find_guard;
                },
                'v' => {
                    dir = 2;
                    break :find_guard;
                },
                '<' => {
                    dir = 3;
                    break :find_guard;
                },
                else => {},
            }
        }
    }

    guard_movement: while (true) {
        var pos_iter = PositionIter{
            .dir = dirs[dir],
            .cur = guard_pos,
        };
        while (true) {
            const pos = pos_iter.next();
            const v = array.at(pos.row, pos.col) orelse break :guard_movement;
            if (v.* == '#') break;
            guard_pos = pos;
            v.* = 'X';
        }

        dir = (dir + 1) % dirs.len;
    }

    var count: u64 = 0;
    for (0..height) |row| {
        for (0..width) |col| {
            const c = array.at(@intCast(row), @intCast(col)).?.*;
            if (c == 'X') count += 1;
        }
    }

    return count;
}

fn part2(alloc: Allocator, input: []u8) !?u64 {
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
    const dirs = [_]Direction{ .{ .dx = 0, .dy = -1 }, .{ .dx = 1, .dy = 0 }, .{ .dx = 0, .dy = 1 }, .{ .dx = -1, .dy = 0 } };

    var initial_dir: usize = undefined;
    var initial_guard_pos: Position = undefined;

    find_guard: for (0..height) |row| {
        for (0..width) |col| {
            const v = array.at(@intCast(row), @intCast(col)).?;
            initial_guard_pos = .{ .col = @intCast(col), .row = @intCast(row) };
            switch (v.*) {
                '^' => {
                    initial_dir = 0;
                    break :find_guard;
                },
                '>' => {
                    initial_dir = 1;
                    break :find_guard;
                },
                'v' => {
                    initial_dir = 2;
                    break :find_guard;
                },
                '<' => {
                    initial_dir = 3;
                    break :find_guard;
                },
                else => {},
            }
        }
    }
    var dir: usize = initial_dir;
    var guard_pos: Position = initial_guard_pos;

    var guard_positions = std.ArrayList(Position).init(alloc);
    defer guard_positions.deinit();
    guard_movement: while (true) {
        var pos_iter = PositionIter{
            .dir = dirs[dir],
            .cur = guard_pos,
        };
        while (true) {
            const pos = pos_iter.next();
            const v = array.at(pos.row, pos.col) orelse {
                break :guard_movement;
            };
            if (v.* == '#') break;
            if (!pos.eq(initial_guard_pos)) try guard_positions.append(pos);
            guard_pos = pos;
            v.* = 'X';
        }

        dir = (dir + 1) % dirs.len;
    }

    var visited_position = std.AutoHashMap(struct { pos: Position, dir: usize }, void).init(alloc);
    defer visited_position.deinit();
    var obstacle_positions = std.AutoHashMap(Position, void).init(alloc);
    defer obstacle_positions.deinit();
    for (guard_positions.items) |recorded_guard_pos| {
        // reset the map
        for (0..height) |row| {
            for (0..width) |col| {
                const v = array.at(@intCast(row), @intCast(col)).?;
                if (v.* == 'X' or v.* == 'O') v.* = '.';
            }
        }
        guard_pos = initial_guard_pos;
        dir = initial_dir;

        // place the obstacle
        array.at(@intCast(recorded_guard_pos.row), @intCast(recorded_guard_pos.col)).?.* = 'O';

        // check for loops
        visited_position.clearRetainingCapacity();
        var is_loop = false;
        guard_movement: while (true) {
            var pos_iter = PositionIter{
                .dir = dirs[dir],
                .cur = guard_pos,
            };
            while (true) {
                const pos = pos_iter.next();
                const v = array.at(pos.row, pos.col) orelse break :guard_movement;
                if (v.* == '#' or v.* == 'O') break;
                const get_or_put = try visited_position.getOrPut(.{ .pos = pos, .dir = dir });
                if (get_or_put.found_existing) {
                    is_loop = true;
                    break :guard_movement;
                }
                get_or_put.value_ptr.* = {};
                guard_pos = pos;
                v.* = 'X';
            }

            dir = (dir + 1) % dirs.len;
        }

        if (is_loop) try obstacle_positions.put(recorded_guard_pos, {});
    }

    return obstacle_positions.count();
}
