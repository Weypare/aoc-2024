const std = @import("std");
const Allocator = std.mem.Allocator;

const DAY = 17;

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

const State = struct {
    A: u64,
    B: u64,
    C: u64,
    Ip: usize = 0,
    program: []const u3,

    const Self = @This();

    fn run(self: *Self, output: *std.ArrayList(u8)) !void {
        while (self.Ip + 1 < self.program.len) {
            try self.step(output);
        }
    }

    fn step(self: *Self, output: *std.ArrayList(u8)) !void {
        const op = self.program[self.Ip];
        switch (op) {
            0 => self.adv(),
            1 => self.bxl(),
            2 => self.bst(),
            3 => self.jnz(),
            4 => self.bxc(),
            5 => try self.out(output),
            6 => self.bdv(),
            7 => self.cdv(),
        }
    }

    fn adv(self: *Self) void {
        self.A = self.A >> @truncate(@min(64, self.combo_operand()));
        self.Ip += 2;
    }
    fn bxl(self: *Self) void {
        self.B = self.B ^ self.literal_operand();
        self.Ip += 2;
    }
    fn bst(self: *Self) void {
        self.B = self.combo_operand() % 8;
        self.Ip += 2;
    }
    fn jnz(self: *Self) void {
        if (self.A == 0) {
            self.Ip += 2;
        } else {
            self.Ip = self.literal_operand();
        }
    }
    fn bxc(self: *Self) void {
        self.B = self.B ^ self.C;
        self.Ip += 2;
    }
    fn out(self: *Self, output: *std.ArrayList(u8)) !void {
        const o: u8 = @truncate(self.combo_operand() % 8);
        try output.append(o + '0');
        self.Ip += 2;
    }
    fn bdv(self: *Self) void {
        self.B = self.A >> @truncate(@min(64, self.combo_operand()));
        self.Ip += 2;
    }
    fn cdv(self: *Self) void {
        self.C = self.A >> @truncate(@min(64, self.combo_operand()));
        self.Ip += 2;
    }

    fn literal_operand(self: *Self) u3 {
        return self.program[self.Ip + 1];
    }
    fn combo_operand(self: *Self) u64 {
        return switch (self.program[self.Ip + 1]) {
            0...3 => self.program[self.Ip + 1],
            4 => self.A,
            5 => self.B,
            6 => self.C,
            7 => std.debug.panic("reserved combo operand value", .{}),
        };
    }
};

fn part1(alloc: Allocator, input: []const u8) !?u64 {
    var state = State{
        .A = undefined,
        .B = undefined,
        .C = undefined,
        .program = undefined,
    };

    var lines_iter = std.mem.splitScalar(u8, input, '\n');

    inline for ([_]*u64{ &state.A, &state.B, &state.C }) |ptr| {
        const line = lines_iter.next().?;
        const idx = std.mem.indexOf(u8, line, ": ").?;
        ptr.* = std.fmt.parseUnsigned(u64, line[idx + 2 ..], 10) catch unreachable;
    }

    var program = try std.ArrayList(u3).initCapacity(alloc, 128);
    defer program.deinit();

    {
        _ = lines_iter.next();
        const line = lines_iter.next().?;
        const idx = std.mem.indexOf(u8, line, ": ").?;
        var opcode_iter = std.mem.splitScalar(u8, line[idx + 2 ..], ',');
        while (opcode_iter.next()) |opcode| {
            const op = std.fmt.parseUnsigned(u3, opcode, 10) catch unreachable;
            try program.append(op);
        }
        state.program = program.items;
    }

    var output = try std.ArrayList(u8).initCapacity(alloc, 1024);
    defer output.deinit();

    try state.run(&output);

    std.debug.print("Output {s}\n", .{output.items});

    return null;
}

fn part2(alloc: Allocator, input: []const u8) !?u64 {
    var state = State{
        .A = undefined,
        .B = undefined,
        .C = undefined,
        .program = undefined,
    };

    var lines_iter = std.mem.splitScalar(u8, input, '\n');

    inline for ([_]*u64{ &state.A, &state.B, &state.C }) |ptr| {
        const line = lines_iter.next().?;
        const idx = std.mem.indexOf(u8, line, ": ").?;
        ptr.* = std.fmt.parseUnsigned(u64, line[idx + 2 ..], 10) catch unreachable;
    }

    var program = try std.ArrayList(u3).initCapacity(alloc, 128);
    defer program.deinit();

    {
        _ = lines_iter.next();
        const line = lines_iter.next().?;
        const idx = std.mem.indexOf(u8, line, ": ").?;
        var opcode_iter = std.mem.splitScalar(u8, line[idx + 2 ..], ',');
        while (opcode_iter.next()) |opcode| {
            const op = std.fmt.parseUnsigned(u3, opcode, 10) catch unreachable;
            try program.append(op);
        }
        state.program = program.items;
    }

    var output = try std.ArrayList(u8).initCapacity(alloc, 1024);
    defer output.deinit();

    var pending = try std.ArrayList(struct { usize, u64 }).initCapacity(alloc, 128);
    defer pending.deinit();
    pending.appendAssumeCapacity(.{ 1, 0 });
    var idx: usize = 0;
    while (idx < pending.items.len) : (idx += 1) {
        const i, const A = pending.items[idx];
        for (A..A + 8) |a| {
            state.A = a;
            state.B = 0;
            state.C = 0;
            state.Ip = 0;

            output.clearRetainingCapacity();
            try state.run(&output);

            var all_equal = true;
            for (program.items[program.items.len - output.items.len ..], output.items) |l, r| {
                if (@as(u8, @intCast(l)) + '0' != r) {
                    all_equal = false;
                    break;
                }
            }
            if (!all_equal) continue;

            if (i == program.items.len) {
                std.debug.print("A={} Output {s}\n", .{ a, output.items });
                return null;
            }
            try pending.append(.{ i + 1, a * 8 });
        }
    }

    return null;
}
