const std = @import("std");
const Allocator = std.mem.Allocator;

const DAY = 14;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    inline for (.{
        .{ "input/{d}.example.txt", Vec2{ .x = 11, .y = 7 } },
        .{ "input/{d}.txt", Vec2{ .x = 101, .y = 103 } },
    }) |item| {
        const path, const room_size = item;
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
            if (try part1(alloc, input, room_size)) |x| std.debug.print("{s:20} part 1: {d}\n", .{ file_path, x });
            if (try part2(alloc, input, room_size)) |x| std.debug.print("{s:20} part 2: {d}\n", .{ file_path, x });
        }
    }
}

const Vec2 = struct { x: i64, y: i64 };

fn parseVec2(input: []const u8) Vec2 {
    const comma_idx = std.mem.indexOfScalar(u8, input, ',').?;
    const x = std.fmt.parseInt(i64, input[0..comma_idx], 10) catch unreachable;
    const y = std.fmt.parseInt(i64, input[comma_idx + 1 ..], 10) catch unreachable;
    return .{ .x = x, .y = y };
}

fn part1(alloc: Allocator, input: []const u8, comptime room_size: Vec2) !?u64 {
    _ = alloc;

    const SIMULATION_STEPS = 100;
    var quadrant_counts: [4]u64 = .{ 0, 0, 0, 0 };

    var lines_iter = std.mem.splitScalar(u8, input, '\n');
    while (lines_iter.next()) |line| {
        if (line.len == 0) continue;
        var equal_idx = std.mem.indexOfScalar(u8, line, '=').?;
        const space_idx = std.mem.indexOfScalar(u8, line, ' ').?;
        const p = parseVec2(line[equal_idx + 1 .. space_idx]);
        equal_idx = std.mem.indexOfScalar(u8, line[space_idx..], '=').?;
        const v = parseVec2(line[space_idx + equal_idx + 1 ..]);

        const final_position = Vec2{ .x = p.x + v.x * SIMULATION_STEPS, .y = p.y + v.y * SIMULATION_STEPS };
        const final_room_position = Vec2{ .x = @mod(final_position.x, room_size.x), .y = @mod(final_position.y, room_size.y) };

        if (final_room_position.x == room_size.x / 2 or final_room_position.y == room_size.y / 2) continue;

        if (final_room_position.x < room_size.x / 2 and final_room_position.y < room_size.y / 2) {
            quadrant_counts[0] += 1;
        } else if (final_room_position.x < room_size.x / 2 and final_room_position.y >= room_size.y / 2) {
            quadrant_counts[1] += 1;
        } else if (final_room_position.x >= room_size.x / 2 and final_room_position.y < room_size.y / 2) {
            quadrant_counts[2] += 1;
        } else {
            quadrant_counts[3] += 1;
        }
    }

    return quadrant_counts[0] * quadrant_counts[1] * quadrant_counts[2] * quadrant_counts[3];
}

// In order to find result pipe the stderr to a file and do `grep -n '#####' <file>` and look for a christmas tree. It
// should look something like this. In case you won't find anything, try adjusting the `SIMULATION_STEPS`.
//
// ###############################
// #.............................#
// #.............................#
// #.............................#
// #.............................#
// #..............#..............#
// #.............###.............#
// #............#####............#
// #...........#######...........#
// #..........#########..........#
// #............#####............#
// #...........#######...........#
// #..........#########..........#
// #.........###########.........#
// #........#############........#
// #..........#########..........#
// #.........###########.........#
// #........#############........#
// #.......###############.......#
// #......#################......#
// #........#############........#
// #.......###############.......#
// #......#################......#
// #.....###################.....#
// #....#####################....#
// #.............###.............#
// #.............###.............#
// #.............###.............#
// #.............................#
// #.............................#
// #.............................#
// #.............................#
// ###############################
fn part2(alloc: Allocator, input: []const u8, comptime room_size: Vec2) !?u64 {
    const SIMULATION_STEPS = 10000;
    const Bot = struct { pos: Vec2, dir: Vec2 };
    var bots = try std.ArrayList(Bot).initCapacity(alloc, 1024);
    defer bots.deinit();
    var lines_iter = std.mem.splitScalar(u8, input, '\n');
    while (lines_iter.next()) |line| {
        if (line.len == 0) continue;
        var equal_idx = std.mem.indexOfScalar(u8, line, '=').?;
        const space_idx = std.mem.indexOfScalar(u8, line, ' ').?;
        const p = parseVec2(line[equal_idx + 1 .. space_idx]);
        equal_idx = std.mem.indexOfScalar(u8, line[space_idx..], '=').?;
        const v = parseVec2(line[space_idx + equal_idx + 1 ..]);

        try bots.append(.{ .pos = p, .dir = v });
    }

    const less_than = struct {
        fn lessThan(_: void, a: Bot, b: Bot) bool {
            return a.pos.y < b.pos.y or (a.pos.y == b.pos.y and a.pos.x < b.pos.x);
        }
    }.lessThan;

    const stride = room_size.x + 1;
    var buf: [room_size.y * stride]u8 = undefined;
    @memset(&buf, '.');
    for (0..room_size.y) |row| {
        buf[row * stride + room_size.x] = '\n';
    }

    for (1..SIMULATION_STEPS) |i| {
        for (bots.items) |*bot| {
            bot.pos.x += bot.dir.x;
            bot.pos.y += bot.dir.y;
            bot.pos.x = @mod(bot.pos.x, room_size.x);
            bot.pos.y = @mod(bot.pos.y, room_size.y);
        }
        std.sort.pdq(Bot, bots.items, {}, less_than);

        var bot_idx: usize = 0;
        std.debug.print("Step {}\n", .{i});
        for (0..room_size.y) |row| {
            for (0..room_size.x) |col| {
                var count: usize = 0;
                while (bot_idx < bots.items.len) {
                    const bot = bots.items[bot_idx];
                    if (bot.pos.x == col and bot.pos.y == row) {
                        count += 1;
                        bot_idx += 1;
                    } else {
                        break;
                    }
                }
                if (count > 0) {
                    buf[row * stride + col] = '#';
                } else {
                    buf[row * stride + col] = '.';
                }
            }
        }
        std.debug.print("{s}\n", .{&buf});
    }

    return null;
}
