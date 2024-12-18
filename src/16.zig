const std = @import("std");
const Allocator = std.mem.Allocator;

const DAY = 16;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    inline for (.{
        "input/{d}.example.txt",
        "input/{d}.txt",
    }) |path| {
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

const Vec2 = struct {
    x: i64,
    y: i64,

    fn add(self: Vec2, other: Vec2) Vec2 {
        return Vec2{ .x = self.x + other.x, .y = self.y + other.y };
    }
    fn subtract(self: Vec2, other: Vec2) Vec2 {
        return Vec2{ .x = self.x - other.x, .y = self.y - other.y };
    }
};

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

fn h(pos: Vec2, goal: Vec2) u64 {
    const diff = goal.subtract(pos);
    return 1000 + @abs(diff.x) + @abs(diff.y);
}

const dirs = [_]Vec2{
    Vec2{ .x = 1, .y = 0 },
    Vec2{ .x = 0, .y = 1 },
    Vec2{ .x = -1, .y = 0 },
    Vec2{ .x = 0, .y = -1 },
};

fn a_star(alloc: Allocator, array: *Array, start: Vec2, goal: Vec2) !?std.ArrayList(Vec2) {
    var g_scores = std.AutoHashMap(Vec2, u64).init(alloc);
    defer g_scores.deinit();
    var f_scores = std.AutoHashMap(Vec2, u64).init(alloc);
    defer f_scores.deinit();
    var came_from = std.AutoHashMap(Vec2, Vec2).init(alloc);
    defer came_from.deinit();

    const OpenSetItem = struct {
        pos: Vec2,
        direction: Vec2,
    };

    const OpenSetContext = struct {
        f_scores: *std.AutoHashMap(Vec2, u64),

        fn compare(ctx: @This(), a: OpenSetItem, b: OpenSetItem) std.math.Order {
            const a_f_score = ctx.f_scores.get(a.pos) orelse std.math.maxInt(u64);
            const b_f_score = ctx.f_scores.get(b.pos) orelse std.math.maxInt(u64);
            return std.math.order(a_f_score, b_f_score);
        }
    };
    const open_set_context = OpenSetContext{ .f_scores = &f_scores };

    var open_set = std.PriorityQueue(OpenSetItem, OpenSetContext, OpenSetContext.compare).init(alloc, open_set_context);
    defer open_set.deinit();

    try open_set.add(.{ .pos = start, .direction = Vec2{ .x = 1, .y = 0 } });
    try g_scores.put(start, 0);
    try f_scores.put(start, h(start, goal));

    while (open_set.removeOrNull()) |current| {
        if (current.pos.x == goal.x and current.pos.y == goal.y) {
            var result = try std.ArrayList(Vec2).initCapacity(alloc, 1024);
            try result.append(current.pos);
            var cur = current.pos;
            while (came_from.get(cur)) |parent| {
                cur = parent;
                try result.append(parent);
            }
            std.mem.reverse(Vec2, result.items);
            return result;
        }

        const current_g_score = g_scores.get(current.pos).?;

        for (dirs) |dir| {
            const neighbor = current.pos.add(dir);
            const neighbor_item = array.at(neighbor.y, neighbor.x);
            if (neighbor_item == null or neighbor_item.?.* != '.') continue;
            const d_to_neighbor: u64 = if (dir.x == current.direction.x and dir.y == current.direction.y) 1 else 1001;
            const neighbor_g_score = current_g_score + d_to_neighbor;
            const recorded_neighbor_g_score = g_scores.get(neighbor) orelse std.math.maxInt(u64);
            if (neighbor_g_score < recorded_neighbor_g_score) {
                try came_from.put(neighbor, current.pos);
                try g_scores.put(neighbor, neighbor_g_score);
                try f_scores.put(neighbor, neighbor_g_score + h(neighbor, goal));

                var contains = false;
                for (open_set.items) |item| {
                    if (item.pos.x == neighbor.x and item.pos.y == neighbor.y) {
                        contains = true;
                        break;
                    }
                }
                if (!contains) try open_set.add(.{ .pos = neighbor, .direction = dir });
            }
        }
    }

    return null;
}

fn path_cost(path: []const Vec2, initial_direction: ?Vec2) u64 {
    var dir = initial_direction orelse Vec2{ .x = 1, .y = 0 };
    var cost: u64 = 0;
    var steps = std.mem.window(Vec2, path, 2, 1);
    while (steps.next()) |step| {
        const prev = step[0];
        const curr = step[1];
        const diff = curr.subtract(prev);
        if (diff.x == dir.x and diff.y == dir.y) {
            cost += 1;
        } else {
            dir = diff;
            cost += 1001;
        }
    }
    return cost;
}

fn part1(alloc: Allocator, input: []u8) !?u64 {
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

    var start: Vec2 = undefined;
    var goal: Vec2 = undefined;
    for (0..height) |row| {
        for (0..width) |col| {
            const r: isize = @intCast(row);
            const c: isize = @intCast(col);
            const item = array.at(r, c).?;
            if (item.* == 'S') {
                item.* = '.';
                start = .{ .y = r, .x = c };
            } else if (item.* == 'E') {
                item.* = '.';
                goal = .{ .y = r, .x = c };
            }
        }
    }

    const path = try a_star(alloc, &array, start, goal) orelse std.debug.panic("path does not exist", .{});
    defer path.deinit();

    return path_cost(path.items, null);
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

    var start: Vec2 = undefined;
    var goal: Vec2 = undefined;
    for (0..height) |row| {
        for (0..width) |col| {
            const r: isize = @intCast(row);
            const c: isize = @intCast(col);
            const item = array.at(r, c).?;
            if (item.* == 'S') {
                item.* = '.';
                start = .{ .y = r, .x = c };
            } else if (item.* == 'E') {
                item.* = '.';
                goal = .{ .y = r, .x = c };
            }
        }
    }

    const shortest_path = try a_star(alloc, &array, start, goal) orelse std.debug.panic("path does not exist", .{});
    defer shortest_path.deinit();
    const shortest_path_cost = path_cost(shortest_path.items, null);

    var all_tiles = std.AutoHashMap(Vec2, void).init(alloc);
    defer all_tiles.deinit();

    for (0..height) |row| {
        for (0..width) |col| {
            const pos = Vec2{ .x = @intCast(col), .y = @intCast(row) };
            const item = array.at(pos.x, pos.y).?.*;
            if (item != '.') continue;
            const start_to_pos = try a_star(alloc, &array, start, pos) orelse continue;
            defer start_to_pos.deinit();
            const pos_to_goal = try a_star(alloc, &array, pos, goal) orelse continue;
            defer pos_to_goal.deinit();

            var pos_to_goal_direction: ?Vec2 = null;
            if (start_to_pos.items.len >= 2) {
                const last = start_to_pos.items[start_to_pos.items.len - 1];
                const last_but_one = start_to_pos.items[start_to_pos.items.len - 2];
                pos_to_goal_direction = last.subtract(last_but_one);
            }
            if (path_cost(start_to_pos.items, null) + path_cost(pos_to_goal.items, pos_to_goal_direction) == shortest_path_cost) {
                for (start_to_pos.items) |tile| try all_tiles.put(tile, {});
                for (pos_to_goal.items) |tile| try all_tiles.put(tile, {});
            }
        }
    }

    return all_tiles.count();
}
