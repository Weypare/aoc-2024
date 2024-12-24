const std = @import("std");
const Allocator = std.mem.Allocator;

const DAY = 22;

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

const Prng = struct {
    secret: u64,

    const Self = @This();

    fn init(secret: u64) Self {
        return .{ .secret = secret };
    }

    fn next(self: *Self) u64 {
        self.secret ^= self.secret << 6;
        self.prune();
        self.secret ^= self.secret >> 5;
        self.prune();
        self.secret ^= self.secret << 11;
        self.prune();
        return self.secret;
    }

    fn prune(self: *Self) void {
        self.secret = self.secret % 16777216;
    }
};

test "prng" {
    var prng = Prng.init(123);
    try std.testing.expectEqual(15887950, prng.next());
    try std.testing.expectEqual(16495136, prng.next());
    try std.testing.expectEqual(527345, prng.next());
    try std.testing.expectEqual(704524, prng.next());
    try std.testing.expectEqual(1553684, prng.next());
    try std.testing.expectEqual(12683156, prng.next());
    try std.testing.expectEqual(11100544, prng.next());
    try std.testing.expectEqual(12249484, prng.next());
    try std.testing.expectEqual(7753432, prng.next());
    try std.testing.expectEqual(5908254, prng.next());
}

fn part1(alloc: Allocator, input: []const u8) !?u64 {
    _ = alloc;
    var line_iter = std.mem.splitScalar(u8, input, '\n');

    var sum: u64 = 0;
    while (line_iter.next()) |line| {
        if (line.len == 0) continue;
        const s = std.fmt.parseUnsigned(u64, line, 10) catch unreachable;
        var prng = Prng.init(s);
        for (0..1999) |_| {
            _ = prng.next();
        }
        sum += prng.next();
    }

    return sum;
}

const RingBuffer = struct {
    buf: []i8,
    first: usize = 0,
    len: usize = 0,

    const Self = @This();

    fn init(buf: []i8) Self {
        return .{ .buf = buf };
    }

    fn push(self: *Self, value: i8) void {
        if (self.len < self.buf.len) {
            self.buf[self.len] = value;
            self.len += 1;
        } else {
            self.buf[self.first] = value;
            self.first = (self.first + 1) % self.buf.len;
        }
    }

    fn copyIntoSlice(self: *const Self, slice: []i8) void {
        std.debug.assert(slice.len == self.len);
        std.mem.copyForwards(i8, slice, self.buf[self.first..]);
        std.mem.copyForwards(i8, slice[self.len - self.first ..], self.buf[0..self.first]);
    }
};

fn part2(alloc: Allocator, input: []const u8) !?u64 {
    var line_iter = std.mem.splitScalar(u8, input, '\n');

    var prices_per_seller_per_seq = std.AutoHashMap([4]i8, std.ArrayList(?i8)).init(alloc);
    defer prices_per_seller_per_seq.deinit();
    defer {
        var value_iter = prices_per_seller_per_seq.valueIterator();
        while (value_iter.next()) |value| value.deinit();
    }

    var seller_idx: usize = 0;
    while (line_iter.next()) |line| : (seller_idx += 1) {
        if (line.len == 0) continue;
        const s = std.fmt.parseUnsigned(u64, line, 10) catch unreachable;
        var prng = Prng.init(s);
        var rb_buf: [4]i8 = undefined;
        var rb = RingBuffer.init(&rb_buf);

        std.debug.print("\rProgress {}", .{seller_idx});
        var prev_price: i8 = @intCast(s % 10);
        for (0..2000) |_| {
            const current_price: i8 = @intCast(prng.next() % 10);
            const price_change = current_price - prev_price;
            rb.push(@intCast(price_change));
            prev_price = current_price;

            if (rb.len == 4) {
                var seq: [4]i8 = undefined;
                rb.copyIntoSlice(&seq);
                const prices_per_seller = try prices_per_seller_per_seq.getOrPut(seq);
                if (!prices_per_seller.found_existing) {
                    prices_per_seller.value_ptr.* = try std.ArrayList(?i8).initCapacity(alloc, 128);
                }
                while (seller_idx >= prices_per_seller.value_ptr.items.len) {
                    try prices_per_seller.value_ptr.append(null);
                }
                if (prices_per_seller.value_ptr.items[seller_idx] == null) {
                    prices_per_seller.value_ptr.items[seller_idx] = current_price;
                }
            }
        }
    }
    std.debug.print("\n", .{});

    var max_value: i32 = 0;
    var iter = prices_per_seller_per_seq.iterator();
    while (iter.next()) |entry| {
        const seq = entry.key_ptr.*;
        const prices_per_seller = entry.value_ptr;

        var sum: i32 = 0;
        for (prices_per_seller.items) |price| {
            if (price) |p| sum += p;
        }
        if (sum > max_value) {
            max_value = sum;
            std.debug.print("New best seq with max_value={}: {any}\n", .{ max_value, seq });
        }
    }

    return @intCast(max_value);
}
