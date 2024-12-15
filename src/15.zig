const std = @import("std");
const Allocator = std.mem.Allocator;

const DAY = 15;

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
            // part 2 does not modify the input so execute it first
            if (try part2(alloc, input)) |x| std.debug.print("{s:20} part 2: {d}\n", .{ file_path, x });
            if (try part1(alloc, input)) |x| std.debug.print("{s:20} part 1: {d}\n", .{ file_path, x });
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
    fn move(self: @This(), dir: Direction) Position {
        return .{ .col = self.col + dir.dx, .row = self.row + dir.dy };
    }
};
const Direction = struct {
    dx: isize,
    dy: isize,
    fn inv(self: @This()) Direction {
        return .{ .dx = -self.dx, .dy = -self.dy };
    }
};

fn part1(alloc: Allocator, input: []u8) !?u64 {
    _ = alloc;

    const input_parts_split_point = std.mem.indexOf(u8, input, "\n\n") orelse unreachable;
    const map = input[0..input_parts_split_point];
    const moves = input[input_parts_split_point + 2 ..];

    const width = std.mem.indexOfScalar(u8, map, '\n').?;
    const stride = width + 1;
    var height: usize = 0;
    {
        var lines_iter = std.mem.splitScalar(u8, map, '\n');
        while (lines_iter.next()) |line| {
            if (line.len == 0) continue;
            height += 1;
        }
    }
    var array = Array{ .buf = map, .stride = stride, .width = width, .height = height };

    var bot_pos: Position = undefined;
    for (0..height) |row| {
        for (0..width) |col| {
            const r: isize = @intCast(row);
            const c: isize = @intCast(col);
            const item = array.at(r, c).?;
            if (item.* == '@') {
                item.* = '.';
                bot_pos = .{ .row = r, .col = c };
                break;
            }
        }
    }

    for (moves) |move| {
        const dir: Direction = switch (move) {
            '^' => .{ .dx = 0, .dy = -1 },
            '>' => .{ .dx = 1, .dy = 0 },
            'v' => .{ .dx = 0, .dy = 1 },
            '<' => .{ .dx = -1, .dy = 0 },
            '\n' => continue,
            else => unreachable,
        };

        const next_pos = bot_pos.move(dir);
        const next_item = array.at(next_pos.row, next_pos.col).?;
        switch (next_item.*) {
            '#' => continue,
            '.' => {
                bot_pos = next_pos;
                continue;
            },
            'O' => {
                var final_pos = next_pos;
                var final_item: u8 = undefined;
                while (true) {
                    final_item = array.at(final_pos.row, final_pos.col).?.*;
                    if (final_item == '.' or final_item == '#') break;
                    final_pos = final_pos.move(dir);
                }

                if (final_item == '.') {
                    bot_pos = next_pos;
                    while (final_pos.row != next_pos.row or final_pos.col != next_pos.col) {
                        array.at(final_pos.row, final_pos.col).?.* = 'O';
                        final_pos = final_pos.move(dir.inv());
                    }
                    array.at(final_pos.row, final_pos.col).?.* = '.';
                }

                continue;
            },
            else => unreachable,
        }
        comptime unreachable;
    }

    var sum: u64 = 0;
    for (0..height) |row| {
        for (0..width) |col| {
            const item = array.at(@intCast(row), @intCast(col)).?.*;
            if (item == 'O') sum += row * 100 + col;
        }
    }

    return sum;
}

fn part2(alloc: Allocator, input: []u8) !?u64 {
    const input_parts_split_point = std.mem.indexOf(u8, input, "\n\n") orelse unreachable;
    const input_map = input[0..input_parts_split_point];
    const moves = input[input_parts_split_point + 2 ..];

    var bot_pos: Position = undefined;
    const map, const stride, const width, const height = blk: {
        const input_width = std.mem.indexOfScalar(u8, input_map, '\n').?;
        const input_stride = input_width + 1;
        var input_height: usize = 0;
        {
            var lines_iter = std.mem.splitScalar(u8, input_map, '\n');
            while (lines_iter.next()) |line| {
                if (line.len == 0) continue;
                input_height += 1;
            }
        }
        var array = Array{ .buf = input_map, .stride = input_stride, .width = input_width, .height = input_height };

        const width = input_width * 2;
        const height = input_height;

        const map = try alloc.alloc(u8, width * height);

        for (0..input_height) |row| {
            for (0..input_width) |col| {
                const idx = row * width + col * 2;
                const item = array.at(@intCast(row), @intCast(col)).?.*;
                switch (item) {
                    '#', '.' => {
                        map[idx] = item;
                        map[idx + 1] = item;
                    },
                    'O' => {
                        map[idx] = '[';
                        map[idx + 1] = ']';
                    },
                    '@' => {
                        map[idx] = '.';
                        map[idx + 1] = '.';
                        bot_pos = .{ .row = @intCast(row), .col = @intCast(col * 2) };
                    },
                    else => unreachable,
                }
            }
        }

        break :blk .{ map, width, width, height };
    };
    defer alloc.free(map);
    var array = Array{ .buf = map, .stride = stride, .width = width, .height = height };

    var moving_positions = try std.ArrayList(Position).initCapacity(alloc, 128);
    defer moving_positions.deinit();
    move_loop: for (moves) |move| {
        const dir: Direction = switch (move) {
            '^' => .{ .dx = 0, .dy = -1 },
            '>' => .{ .dx = 1, .dy = 0 },
            'v' => .{ .dx = 0, .dy = 1 },
            '<' => .{ .dx = -1, .dy = 0 },
            '\n' => continue,
            else => unreachable,
        };

        const next_pos = bot_pos.move(dir);
        const next_item = array.at(next_pos.row, next_pos.col).?.*;
        switch (next_item) {
            '#' => continue,
            '.' => {
                bot_pos = next_pos;
                continue;
            },
            '[', ']' => {
                // simple case, reuse the logic from part 1
                if (move == '>' or move == '<') {
                    var final_pos = next_pos;
                    var final_item: u8 = undefined;
                    while (true) {
                        final_item = array.at(final_pos.row, final_pos.col).?.*;
                        if (final_item == '.' or final_item == '#') break;
                        final_pos = final_pos.move(dir);
                    }

                    if (final_item == '.') {
                        bot_pos = next_pos;
                        const first_char: u8, const second_char: u8 = if (move == '<') .{ '[', ']' } else .{ ']', '[' };

                        while (final_pos.col != next_pos.col) {
                            array.at(final_pos.row, final_pos.col).?.* = first_char;
                            final_pos = final_pos.move(dir.inv());
                            array.at(final_pos.row, final_pos.col).?.* = second_char;
                            final_pos = final_pos.move(dir.inv());
                        }
                        array.at(final_pos.row, final_pos.col).?.* = '.';
                    }
                } else {
                    moving_positions.clearRetainingCapacity();
                    if (next_item == '[') {
                        try moving_positions.append(next_pos);
                        try moving_positions.append(.{ .row = next_pos.row, .col = next_pos.col + 1 });
                    } else {
                        try moving_positions.append(.{ .row = next_pos.row, .col = next_pos.col - 1 });
                        try moving_positions.append(next_pos);
                    }

                    // ..............
                    // ..[][][][][]..
                    // ...[][][][]...
                    // ....[][][]....
                    // .....[][].....
                    // ......[]......
                    // ......@.......

                    // we need to check only the top/bottom row of known affected boxes to make decision if we continue
                    var topmost_boxes_offset: usize = 0;
                    while (true) {
                        var all_free = true;
                        const current_iter_len = moving_positions.items.len;
                        for (topmost_boxes_offset..current_iter_len) |i| {
                            const pos = moving_positions.items[i];
                            const final_pos = pos.move(dir);
                            const item = array.at(final_pos.row, final_pos.col).?.*;
                            if (item != '.') {
                                all_free = false;
                            }
                            if (item == '#') {
                                continue :move_loop;
                            } else if (item == '[') {
                                const l_pos = final_pos;
                                const r_pos = .{ .row = final_pos.row, .col = final_pos.col + 1 };
                                find_same_pos: for ([_]Position{ l_pos, r_pos }) |box_pos| {
                                    for (moving_positions.items[current_iter_len..]) |p| {
                                        if (p.row == box_pos.row and p.col == box_pos.col) break :find_same_pos;
                                    }
                                    try moving_positions.append(box_pos);
                                }
                            } else if (item == ']') {
                                const l_pos = .{ .row = final_pos.row, .col = final_pos.col - 1 };
                                const r_pos = final_pos;
                                find_same_pos: for ([_]Position{ l_pos, r_pos }) |box_pos| {
                                    for (moving_positions.items[current_iter_len..]) |p| {
                                        if (p.row == box_pos.row and p.col == box_pos.col) break :find_same_pos;
                                    }
                                    try moving_positions.append(box_pos);
                                }
                            } else if (item == '.') {} else {
                                unreachable;
                            }

                            topmost_boxes_offset = current_iter_len;
                        }
                        if (all_free) break;
                    }

                    // push boxes up/down
                    bot_pos = next_pos;
                    var slice = moving_positions.items;
                    while (slice.len > 0) {
                        const last_row = slice[slice.len - 1].row;
                        var last_row_count: usize = 1;
                        while (last_row_count < slice.len and slice[slice.len - 1 - last_row_count].row == last_row) {
                            last_row_count += 1;
                        }

                        for (slice[slice.len - last_row_count ..]) |last_row_pos| {
                            const last_row_next_pos = last_row_pos.move(dir);
                            const last_row_pos_item = array.at(last_row_pos.row, last_row_pos.col).?;
                            array.at(last_row_next_pos.row, last_row_next_pos.col).?.* = last_row_pos_item.*;
                            last_row_pos_item.* = '.';
                        }
                        slice = slice[0 .. slice.len - last_row_count];
                    }
                }

                continue;
            },
            else => unreachable,
        }
        comptime unreachable;
    }

    var sum: u64 = 0;
    for (0..height) |row| {
        for (0..width) |col| {
            const item = array.at(@intCast(row), @intCast(col)).?.*;
            if (item == '[') sum += row * 100 + col;
        }
    }

    return sum;
}
