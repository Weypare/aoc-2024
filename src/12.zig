const std = @import("std");
const Allocator = std.mem.Allocator;

const DAY = 12;

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

const Position = struct {
    row: isize,
    col: isize,
};

const SideDir = enum { vertical, horizontal };

const Region = struct {
    positions: std.ArrayList(Position),
    item: u8,

    const Self = @This();

    fn area(self: *const Self) u64 {
        return self.positions.items.len;
    }

    fn perimeter(self: *const Self, array: *const Array) u64 {
        var p: u64 = 0;
        for (self.positions.items) |pos| {
            for (makeNeighbors(pos)) |n| {
                if (array.at(n.row, n.col)) |v| {
                    if (v != self.item) p += 1;
                } else {
                    p += 1;
                }
            }
        }
        return p;
    }

    fn side_count(self: *Self, array: *const Array) u64 {
        var sides: u64 = 0;

        const less_then_row = struct {
            fn lessThen(_: void, lhs: Position, rhs: Position) bool {
                return lhs.row < rhs.row;
            }
        }.lessThen;
        const less_then_col = struct {
            fn lessThen(_: void, lhs: Position, rhs: Position) bool {
                return lhs.col < rhs.col;
            }
        }.lessThen;

        // top/bottom sides
        {
            std.sort.block(Position, self.positions.items, {}, less_then_col);
            std.sort.block(Position, self.positions.items, {}, less_then_row);
            inline for (.{ -1, 1 }) |offset| {
                var active_pos: ?Position = null;
                for (self.positions.items) |pos| {
                    const neighbor_pos: Position = .{ .row = pos.row + offset, .col = pos.col };
                    const neighbor = array.at(neighbor_pos.row, neighbor_pos.col);
                    const has_side = neighbor == null or neighbor.? != self.item;
                    if (active_pos != null and (pos.row != active_pos.?.row or pos.col != active_pos.?.col + 1)) {
                        sides += 1;
                        active_pos = null;
                    }
                    if (active_pos != null) {
                        if (has_side) {
                            active_pos = pos;
                        } else {
                            sides += 1;
                            active_pos = null;
                        }
                    } else {
                        if (has_side) {
                            active_pos = pos;
                        }
                    }
                }
                if (active_pos != null) {
                    sides += 1;
                }
            }
        }

        // left/right sides
        {
            std.sort.block(Position, self.positions.items, {}, less_then_row);
            std.sort.block(Position, self.positions.items, {}, less_then_col);
            inline for (.{ -1, 1 }) |offset| {
                var active_pos: ?Position = null;
                for (self.positions.items) |pos| {
                    const left_neighbor_pos: Position = .{ .row = pos.row, .col = pos.col + offset };
                    const left_neighbor = array.at(left_neighbor_pos.row, left_neighbor_pos.col);
                    const has_left_side = left_neighbor == null or left_neighbor.? != self.item;
                    if (active_pos != null and (pos.col != active_pos.?.col or pos.row != active_pos.?.row + 1)) {
                        sides += 1;
                        active_pos = null;
                    }
                    if (active_pos != null) {
                        if (has_left_side) {
                            active_pos = pos;
                        } else {
                            sides += 1;
                            active_pos = null;
                        }
                    } else {
                        if (has_left_side) {
                            active_pos = pos;
                        }
                    }
                }
                if (active_pos != null) {
                    sides += 1;
                }
            }
        }

        return sides;
    }

    fn deinit(self: *Self) void {
        self.positions.deinit();
    }
};

fn makeNeighbors(pos: Position) [4]Position {
    return [_]Position{
        .{ .row = pos.row + 1, .col = pos.col },
        .{ .row = pos.row - 1, .col = pos.col },
        .{ .row = pos.row, .col = pos.col + 1 },
        .{ .row = pos.row, .col = pos.col - 1 },
    };
}

fn collectRegion(array: *const Array, item: u8, start: Position, positions: *std.ArrayList(Position), seen_positions: *std.AutoHashMap(Position, void)) !void {
    if (seen_positions.contains(start)) return;
    if (array.at(start.row, start.col) != item) return;
    try positions.append(start);
    try seen_positions.put(start, {});

    for (makeNeighbors(start)) |p| {
        try collectRegion(array, item, p, positions, seen_positions);
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

    const array = Array{ .buf = input, .stride = stride, .width = width, .height = height };

    var seen = std.AutoHashMap(Position, void).init(alloc);
    defer seen.deinit();
    var regions = try std.ArrayList(Region).initCapacity(alloc, 128);
    defer regions.deinit();
    defer for (regions.items) |*region| region.deinit();

    for (0..height) |row| {
        for (0..width) |col| {
            const pos = Position{ .row = @intCast(row), .col = @intCast(col) };
            if (seen.contains(pos)) continue;
            const item = array.at(pos.row, pos.col) orelse unreachable;

            var region = Region{
                .positions = try std.ArrayList(Position).initCapacity(alloc, 128),
                .item = item,
            };

            try collectRegion(&array, item, pos, &region.positions, &seen);
            try regions.append(region);
        }
    }

    var sum: u64 = 0;
    for (regions.items) |region| {
        const area = region.area();
        const perimeter = region.perimeter(&array);
        sum += area * perimeter;
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

    const array = Array{ .buf = input, .stride = stride, .width = width, .height = height };

    var seen = std.AutoHashMap(Position, void).init(alloc);
    defer seen.deinit();
    var regions = try std.ArrayList(Region).initCapacity(alloc, 128);
    defer regions.deinit();
    defer for (regions.items) |*region| region.deinit();

    for (0..height) |row| {
        for (0..width) |col| {
            const pos = Position{ .row = @intCast(row), .col = @intCast(col) };
            if (seen.contains(pos)) continue;
            const item = array.at(pos.row, pos.col) orelse unreachable;

            var region = Region{
                .positions = try std.ArrayList(Position).initCapacity(alloc, 128),
                .item = item,
            };

            try collectRegion(&array, item, pos, &region.positions, &seen);
            try regions.append(region);
        }
    }

    var sum: u64 = 0;
    for (regions.items) |*region| sum += region.area() * region.side_count(&array);

    return sum;
}
