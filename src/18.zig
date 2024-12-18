const std = @import("std");
const Allocator = std.mem.Allocator;

const DAY = 18;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    inline for (.{ .{ "input/{d}.example.txt", Vec2{ .x = 7, .y = 7 }, 12 }, .{ "input/{d}.txt", Vec2{ .x = 71, .y = 71 }, 1024 } }) |i| {
        const path, const size, const simulation_steps = i;
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
            if (try part1(alloc, input, size, simulation_steps)) |x| std.debug.print("{s:20} part 1: {d}\n", .{ file_path, x });
            if (try part2(alloc, input, size)) |x| std.debug.print("{s:20} part 2: {d}\n", .{ file_path, x });
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

    fn rowvise_less_than(a: Vec2, b: Vec2) bool {
        return a.y < b.y or (a.y == b.y and a.x < b.x);
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

const dirs = [_]Vec2{
    Vec2{ .x = 1, .y = 0 },
    Vec2{ .x = 0, .y = 1 },
    Vec2{ .x = -1, .y = 0 },
    Vec2{ .x = 0, .y = -1 },
};

fn h(pos: Vec2, goal: Vec2) u64 {
    const diff = goal.subtract(pos);
    return @abs(diff.x) + @abs(diff.y);
}

fn a_star(alloc: Allocator, array: *Array, start: Vec2, goal: Vec2) !?std.ArrayList(Vec2) {
    var g_scores = std.AutoHashMap(Vec2, u64).init(alloc);
    defer g_scores.deinit();
    var f_scores = std.AutoHashMap(Vec2, u64).init(alloc);
    defer f_scores.deinit();
    var came_from = std.AutoHashMap(Vec2, Vec2).init(alloc);
    defer came_from.deinit();

    const OpenSetItem = Vec2;

    const OpenSetContext = struct {
        f_scores: *std.AutoHashMap(Vec2, u64),

        fn compare(ctx: @This(), a: OpenSetItem, b: OpenSetItem) std.math.Order {
            const a_f_score = ctx.f_scores.get(a) orelse std.math.maxInt(u64);
            const b_f_score = ctx.f_scores.get(b) orelse std.math.maxInt(u64);
            return std.math.order(a_f_score, b_f_score);
        }
    };
    const open_set_context = OpenSetContext{ .f_scores = &f_scores };

    var open_set = std.PriorityQueue(OpenSetItem, OpenSetContext, OpenSetContext.compare).init(alloc, open_set_context);
    defer open_set.deinit();

    try open_set.add(start);
    try g_scores.put(start, 0);
    try f_scores.put(start, h(start, goal));

    while (open_set.removeOrNull()) |current| {
        if (current.x == goal.x and current.y == goal.y) {
            var result = try std.ArrayList(Vec2).initCapacity(alloc, 1024);
            try result.append(current);
            var cur = current;
            while (came_from.get(cur)) |parent| {
                cur = parent;
                try result.append(parent);
            }
            std.mem.reverse(Vec2, result.items);
            return result;
        }

        const current_g_score = g_scores.get(current).?;

        for (dirs) |dir| {
            const neighbor = current.add(dir);
            const neigbor_item = array.at(neighbor.y, neighbor.x);
            if (neigbor_item == null or neigbor_item.?.* != '.') continue;
            const neigbor_g_score = current_g_score + 1;
            const recorded_neigbor_g_score = g_scores.get(neighbor) orelse std.math.maxInt(u64);
            if (neigbor_g_score < recorded_neigbor_g_score) {
                try came_from.put(neighbor, current);
                try g_scores.put(neighbor, neigbor_g_score);
                try f_scores.put(neighbor, neigbor_g_score + h(neighbor, goal));

                var contains = false;
                for (open_set.items) |item| {
                    if (item.x == neighbor.x and item.y == neighbor.y) {
                        contains = true;
                        break;
                    }
                }
                if (!contains) try open_set.add(neighbor);
            }
        }
    }

    return null;
}

fn part1(alloc: Allocator, input: []const u8, comptime size: Vec2, comptime simulation_steps: usize) !?u64 {
    var buf = [_]u8{'.'} ** (size.x * size.y);
    var array = Array{ .buf = &buf, .stride = size.x, .width = size.x, .height = size.y };
    var line_iter = std.mem.splitScalar(u8, input, '\n');
    for (0..simulation_steps) |_| {
        const line = line_iter.next().?;
        const comma_idx = std.mem.indexOfScalar(u8, line, ',').?;
        const x = std.fmt.parseInt(isize, line[0..comma_idx], 10) catch unreachable;
        const y = std.fmt.parseInt(isize, line[comma_idx + 1 ..], 10) catch unreachable;
        array.at(y, x).?.* = '#';
    }

    const path = (try a_star(alloc, &array, Vec2{ .x = 0, .y = 0 }, Vec2{ .x = size.x - 1, .y = size.y - 1 })).?;
    defer path.deinit();

    return path.items.len - 1;
}

fn part2(alloc: Allocator, input: []const u8, comptime size: Vec2) !?u64 {
    var line_iter = std.mem.splitScalar(u8, input, '\n');

    var bytes = try std.ArrayList(Vec2).initCapacity(alloc, 1024);
    defer bytes.deinit();

    while (line_iter.next()) |line| {
        if (line.len == 0) continue;
        const comma_idx = std.mem.indexOfScalar(u8, line, ',').?;
        const x = std.fmt.parseInt(isize, line[0..comma_idx], 10) catch unreachable;
        const y = std.fmt.parseInt(isize, line[comma_idx + 1 ..], 10) catch unreachable;
        try bytes.append(Vec2{ .x = x, .y = y });
    }

    var lo: usize = 0;
    var hi: usize = bytes.items.len;

    while (lo < hi) {
        const mid = (lo + hi) / 2;
        var buf = [_]u8{'.'} ** (size.x * size.y);
        var array = Array{ .buf = &buf, .stride = size.x, .width = size.x, .height = size.y };
        for (0..mid + 1) |i| {
            const v = bytes.items[i];
            array.at(v.y, v.x).?.* = '#';
        }
        const maybe_path = try a_star(alloc, &array, Vec2{ .x = 0, .y = 0 }, Vec2{ .x = size.x - 1, .y = size.y - 1 });
        defer if (maybe_path) |p| p.deinit();
        if (maybe_path == null) {
            std.debug.print("no path at mid={} {any}\n", .{ mid, bytes.items[mid] });
            hi = mid;
        } else {
            std.debug.print("   path at mid={} {any}\n", .{ mid, bytes.items[mid] });
            lo = mid + 1;
        }
    }

    std.debug.print("lo {d} hi {d} {any} {any}\n", .{ lo, hi, bytes.items[lo], bytes.items[hi] });

    return null;
}
