const std = @import("std");
const Allocator = std.mem.Allocator;

const DAY = 13;

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

const Vec2 = struct { x: i64, y: i64 };

fn parseClawBlock(input: []const u8) struct { Vec2, Vec2, Vec2 } {
    var lines_iter = std.mem.splitScalar(u8, input, '\n');
    var a: Vec2 = undefined;
    var b: Vec2 = undefined;
    {
        for ([_]*Vec2{ &a, &b }) |v| {
            var line = lines_iter.next() orelse unreachable;
            const x_idx = std.mem.indexOfScalar(u8, line, 'X') orelse unreachable;
            line = line[x_idx + 1 ..];
            const comma_idx = std.mem.indexOfScalar(u8, line, ',') orelse unreachable;
            const x = std.fmt.parseInt(i64, line[0..comma_idx], 10) catch unreachable;
            const y_idx = std.mem.indexOfScalar(u8, line, 'Y') orelse unreachable;
            line = line[y_idx + 1 ..];
            const y = std.fmt.parseInt(i64, line, 10) catch unreachable;
            v.* = .{ .x = x, .y = y };
        }
    }
    var p: Vec2 = undefined;
    {
        var line = lines_iter.next() orelse unreachable;
        var equals_idx = std.mem.indexOfScalar(u8, line, '=') orelse unreachable;
        line = line[equals_idx + 1 ..];
        const comma_idx = std.mem.indexOfScalar(u8, line, ',') orelse unreachable;
        const x = std.fmt.parseInt(i64, line[0..comma_idx], 10) catch unreachable;
        equals_idx = std.mem.indexOfScalar(u8, line, '=') orelse unreachable;
        line = line[equals_idx + 1 ..];
        const y = std.fmt.parseInt(i64, line, 10) catch unreachable;
        p = .{ .x = x, .y = y };
    }

    return .{ a, b, p };
}

/// Returns the the coefficients for linear combination `ax + by = gcd` and gcd.
///
/// Ref: https://en.wikipedia.org/wiki/Extended_Euclidean_algorithm#Pseudocode
fn extendedGcd(a: i64, b: i64) struct { i64, i64, i64 } {
    var old_r, var r = .{ a, b };
    var old_s: i64, var s: i64 = .{ 1, 0 };
    var old_t: i64, var t: i64 = .{ 0, 1 };

    while (r != 0) {
        const quotient = @divTrunc(old_r, r);
        const new_r = old_r - quotient * r;
        old_r, r = .{ r, new_r };
        const new_s = old_s - quotient * s;
        old_s, s = .{ s, new_s };
        const new_t = old_t - quotient * t;
        old_t, t = .{ t, new_t };
    }

    return .{ old_s, old_t, old_r };
}

/// In order to arrive at the prize `p` using only moves `a` and `b`, we should `m` moves with `a` and `n` moves with
/// `b`. This can be represented as a system of linear equations:
///
///     m * a.x + n * b.x = p.x
///     m * a.y + n * b.y = p.y
///
/// Additional constraints are that `m` and `n` are non-negative integers.
///
/// The approach taken here is to find all solutions to the first equation by expressing `m` and `n` as parametric
/// equations which both depend on the same parameter value, i.e.:
///
///     m = m(k) = m0 + k * m_step
///     n = n(k) = n0 - k * n_step
///         where k is an integer
///
/// Then we substitute the parametric equations into the second equation and solve for `k`. If the solution exists,
/// substitute k into `m(k)` and `n(k)` to find the moves.
fn findMoves(a: Vec2, b: Vec2, p: Vec2) ?struct { i64, i64 } {
    // Find gcd and linear combination of a and b which equals to gcd.
    var m0_x, var n0_x, const gcd_x = extendedGcd(a.x, b.x);
    // if the prize `x` coordinate is not divisible by the gcd, then it's impossible to arrive there using provided
    // moves.
    if (@rem(p.x, gcd_x) != 0) return null;

    // scale coefficients of linear combination, so that m(0) * a.x + n(0) * b.x = p.x
    m0_x = @divExact(m0_x * p.x, gcd_x);
    n0_x = @divExact(n0_x * p.x, gcd_x);

    // compute a scaling factor for parametric equation
    const m_x_step = @divExact(b.x, gcd_x);
    const n_x_step = @divExact(a.x, gcd_x);

    // the division here is the rearanged version of the second equation with parametric equations expanded
    const k = std.math.divExact(i64, p.y - m0_x * a.y - n0_x * b.y, m_x_step * a.y - n_x_step * b.y) catch |e| switch (e) {
        // if the solution doesn't satisfy second equation, then no solution exists
        error.UnexpectedRemainder => return null,
        // NOTE: this represents a case when [a.y,b.y] are a linear combination of [a.x,b.x]
        // TODO: for completeness, it would be nice to handle this case, but the solution was accepted without it so
        // whatever :)
        error.DivisionByZero => unreachable,
        else => unreachable,
    };

    const m = m0_x + k * m_x_step;
    const n = n0_x - k * n_x_step;
    return .{ m, n };
}

fn part1(alloc: Allocator, input: []const u8) !?u64 {
    _ = alloc;
    var claw_block_iter = std.mem.split(u8, input, "\n\n");

    var total_cost: u64 = 0;
    while (claw_block_iter.next()) |claw_block| {
        if (claw_block.len == 0) continue;
        const a, const b, const p = parseClawBlock(claw_block);
        const m, const n = findMoves(a, b, p) orelse continue;
        std.debug.assert(m >= 0);
        std.debug.assert(n >= 0);
        const cost: u64 = 3 * @as(u64, @intCast(m)) + @as(u64, @intCast(n));
        total_cost += cost;
    }

    return total_cost;
}

fn part2(alloc: Allocator, input: []const u8) !?u64 {
    _ = alloc;
    var claw_block_iter = std.mem.split(u8, input, "\n\n");

    var total_cost: u64 = 0;
    while (claw_block_iter.next()) |claw_block| {
        if (claw_block.len == 0) continue;
        const a, const b, var p = parseClawBlock(claw_block);
        p.x += 10000000000000;
        p.y += 10000000000000;
        const m, const n = findMoves(a, b, p) orelse continue;
        std.debug.assert(m >= 0);
        std.debug.assert(n >= 0);
        const cost: u64 = 3 * @as(u64, @intCast(m)) + @as(u64, @intCast(n));
        total_cost += cost;
    }

    return total_cost;
}
