const std = @import("std");
const Allocator = std.mem.Allocator;

const DAY = 21;

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

const Vec2 = struct {
    x: i64,
    y: i64,

    fn add(self: Vec2, other: Vec2) Vec2 {
        return Vec2{ .x = self.x + other.x, .y = self.y + other.y };
    }
    fn subtract(self: Vec2, other: Vec2) Vec2 {
        return Vec2{ .x = self.x - other.x, .y = self.y - other.y };
    }
    fn rowviseLessThan(a: Vec2, b: Vec2) bool {
        return a.y < b.y or (a.y == b.y and a.x < b.x);
    }
};

const FromTo = struct { from: u8, to: u8 };
const Path = std.ArrayList(u8);
const ShortestPathsCache = std.AutoHashMap(FromTo, std.ArrayList(Path));

const KeyPosition = struct { u8, Vec2 };

fn buildShortestPaths(key_positions: []const KeyPosition, empty_cell: Vec2, alloc: Allocator, out: *ShortestPathsCache) !void {
    for (key_positions) |from_kp| {
        const from, const from_pos = from_kp;
        for (key_positions) |to_kp| {
            const to, const to_pos = to_kp;
            if (from == to) continue;
            var paths = try std.ArrayList(Path).initCapacity(alloc, 4);
            const diff = to_pos.subtract(from_pos);
            const vertical_dir: u8 = if (diff.y > 0) 'v' else '^';
            const horizontal_dir: u8 = if (diff.x > 0) '>' else '<';
            const remaining_horizontal = @abs(diff.x);
            const remaining_vertical = @abs(diff.y);
            if (!(from_pos.x == empty_cell.x and from_pos.y + diff.y == empty_cell.y)) {
                var p1 = try Path.initCapacity(alloc, 8);
                try p1.appendNTimes(vertical_dir, remaining_vertical);
                try p1.appendNTimes(horizontal_dir, remaining_horizontal);
                try paths.append(p1);
            }
            if (!(from_pos.y == empty_cell.y and from_pos.x + diff.x == empty_cell.x)) {
                var p2 = try Path.initCapacity(alloc, 8);
                try p2.appendNTimes(horizontal_dir, remaining_horizontal);
                try p2.appendNTimes(vertical_dir, remaining_vertical);
                try paths.append(p2);
            }
            try out.put(FromTo{ .from = from, .to = to }, paths);
        }
    }
}

fn buildNumpadShortestPaths(alloc: Allocator, out: *ShortestPathsCache) !void {
    const key_positions: []const KeyPosition = &.{
        .{ '0', Vec2{ .x = 1, .y = 3 } },
        .{ '1', Vec2{ .x = 0, .y = 2 } },
        .{ '2', Vec2{ .x = 1, .y = 2 } },
        .{ '3', Vec2{ .x = 2, .y = 2 } },
        .{ '4', Vec2{ .x = 0, .y = 1 } },
        .{ '5', Vec2{ .x = 1, .y = 1 } },
        .{ '6', Vec2{ .x = 2, .y = 1 } },
        .{ '7', Vec2{ .x = 0, .y = 0 } },
        .{ '8', Vec2{ .x = 1, .y = 0 } },
        .{ '9', Vec2{ .x = 2, .y = 0 } },
        .{ 'A', Vec2{ .x = 2, .y = 3 } },
    };
    try buildShortestPaths(key_positions, .{ .x = 0, .y = 3 }, alloc, out);
}

fn buildDirpadShortestPaths(alloc: Allocator, out: *ShortestPathsCache) !void {
    const key_positions: []const KeyPosition = &.{
        .{ 'v', Vec2{ .x = 1, .y = 1 } },
        .{ '^', Vec2{ .x = 1, .y = 0 } },
        .{ '<', Vec2{ .x = 0, .y = 1 } },
        .{ '>', Vec2{ .x = 2, .y = 1 } },
        .{ 'A', Vec2{ .x = 2, .y = 0 } },
    };
    try buildShortestPaths(key_positions, .{ .x = 0, .y = 0 }, alloc, out);
}

const CacheItem = struct {
    depth: usize,
    keys: Path,
    fn deinit(self: *@This()) void {
        self.keys.deinit();
    }
};
const CacheItemContext = struct {
    pub fn hash(_: @This(), item: CacheItem) u64 {
        return CacheItemBorrowedContext.hash(.{}, .{ .depth = item.depth, .keys = item.keys.items });
    }
    pub fn eql(_: @This(), a: CacheItem, b: CacheItem) bool {
        return CacheItemBorrowedContext.eql(.{}, .{ .depth = a.depth, .keys = a.keys.items }, b);
    }
};
const CacheItemBorrowed = struct { depth: usize, keys: []const u8 };
const CacheItemBorrowedContext = struct {
    pub fn hash(_: @This(), item: CacheItemBorrowed) u64 {
        var hasher = std.hash.Wyhash.init(0);
        std.hash.autoHash(&hasher, item.depth);
        for (item.keys) |key| std.hash.autoHash(&hasher, key);
        return hasher.final();
    }
    pub fn eql(_: @This(), a: CacheItemBorrowed, b: CacheItem) bool {
        return a.depth == b.depth and std.mem.eql(u8, a.keys, b.keys.items);
    }
};

fn buildSequences(
    input: []const u8,
    index: usize,
    prev_key: u8,
    curr_path: *Path,
    result: *std.ArrayList(Path),
    shortest_paths: *const ShortestPathsCache,
) !void {
    if (index == input.len) {
        try result.append(try curr_path.clone());
        return;
    }
    const curr_key = input[index];

    const maybe_paths = shortest_paths.get(.{ .from = prev_key, .to = curr_key });
    const cur_path_initial_len = curr_path.items.len;
    if (maybe_paths) |paths| {
        for (paths.items) |path| {
            curr_path.shrinkRetainingCapacity(cur_path_initial_len);
            try curr_path.appendSlice(path.items);
            try curr_path.append('A');
            try buildSequences(input, index + 1, curr_key, curr_path, result, shortest_paths);
        }
    } else {
        curr_path.shrinkRetainingCapacity(cur_path_initial_len);
        try curr_path.append('A');
        try buildSequences(input, index + 1, curr_key, curr_path, result, shortest_paths);
    }
}

fn directionalToDirectionalLength(
    alloc: Allocator,
    input: []const u8,
    depth: usize,
    cache: *std.HashMap(CacheItem, u64, CacheItemContext, std.hash_map.default_max_load_percentage),
    shortest_paths: *const ShortestPathsCache,
) !u64 {
    if (depth == 0) return input.len;
    if (cache.getAdapted(CacheItemBorrowed{ .keys = input, .depth = depth }, CacheItemBorrowedContext{})) |value| return value;

    var sequences = try std.ArrayList(Path).initCapacity(alloc, 16);
    defer sequences.deinit();
    defer for (sequences.items) |path| path.deinit();
    var build_sequences_cur_path = try Path.initCapacity(alloc, 128);
    defer build_sequences_cur_path.deinit();
    var slice = input;
    var total: u64 = 0;
    while (slice.len > 0) {
        const A_idx = std.mem.indexOfScalar(u8, slice, 'A').?;
        defer slice = slice[A_idx + 1 ..];
        const section = slice[0 .. A_idx + 1];

        for (sequences.items) |path| path.deinit();
        sequences.clearRetainingCapacity();
        build_sequences_cur_path.clearRetainingCapacity();
        try buildSequences(section, 0, 'A', &build_sequences_cur_path, &sequences, shortest_paths);

        var shortest: u64 = std.math.maxInt(u64);
        for (sequences.items) |sequence| {
            const c = try directionalToDirectionalLength(alloc, sequence.items, depth - 1, cache, shortest_paths);
            if (c < shortest) shortest = c;
        }
        total += shortest;
    }

    var owned_input = try Path.initCapacity(alloc, input.len);
    owned_input.appendSliceAssumeCapacity(input);
    try cache.put(CacheItem{ .depth = depth, .keys = owned_input }, total);

    return total;
}

fn impl(alloc: Allocator, input: []const u8, depth: usize) !?u64 {
    var numpad_sequences = try std.ArrayList(Path).initCapacity(alloc, 16);
    defer numpad_sequences.deinit();
    defer for (numpad_sequences.items) |path| path.deinit();
    var build_sequences_cur_path = try Path.initCapacity(alloc, 128);
    defer build_sequences_cur_path.deinit();

    var numpad_shortest_paths = ShortestPathsCache.init(alloc);
    defer numpad_shortest_paths.deinit();
    defer {
        var iter = numpad_shortest_paths.valueIterator();
        while (iter.next()) |paths| {
            for (paths.items) |path| path.deinit();
            paths.deinit();
        }
    }
    try buildNumpadShortestPaths(alloc, &numpad_shortest_paths);
    var dirpad_shortest_paths = ShortestPathsCache.init(alloc);
    defer dirpad_shortest_paths.deinit();
    defer {
        var iter = dirpad_shortest_paths.valueIterator();
        while (iter.next()) |paths| {
            for (paths.items) |path| path.deinit();
            paths.deinit();
        }
    }
    try buildDirpadShortestPaths(alloc, &dirpad_shortest_paths);

    var cache = std.HashMap(CacheItem, u64, CacheItemContext, std.hash_map.default_max_load_percentage).init(alloc);
    defer cache.deinit();
    defer {
        var iter = cache.keyIterator();
        while (iter.next()) |x| x.deinit();
    }

    var sum: u64 = 0;
    var line_iter = std.mem.splitScalar(u8, input, '\n');
    while (line_iter.next()) |line| {
        if (line.len == 0) continue;

        for (numpad_sequences.items) |path| path.deinit();
        numpad_sequences.clearRetainingCapacity();
        build_sequences_cur_path.clearRetainingCapacity();
        try buildSequences(line, 0, 'A', &build_sequences_cur_path, &numpad_sequences, &numpad_shortest_paths);

        var shortest: u64 = std.math.maxInt(u64);
        for (numpad_sequences.items) |n| {
            const c = try directionalToDirectionalLength(alloc, n.items, depth - 1, &cache, &dirpad_shortest_paths);
            if (c < shortest) shortest = c;
        }

        var num_count: usize = 0;
        while (std.ascii.isDigit(line[num_count])) num_count += 1;
        const n = std.fmt.parseUnsigned(u64, line[0..num_count], 10) catch unreachable;
        const complexity = n * shortest;
        sum += complexity;
        std.debug.print("{s}: complexity {} len {} num {}\n", .{ line, complexity, shortest, n });
    }

    return sum;
}

fn part1(alloc: Allocator, input: []const u8) !?u64 {
    return impl(alloc, input, 3);
}

fn part2(alloc: Allocator, input: []const u8) !?u64 {
    return impl(alloc, input, 26);
}
