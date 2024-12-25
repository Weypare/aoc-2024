const std = @import("std");
const Allocator = std.mem.Allocator;

const DAY = 24;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    inline for (.{ .{ "input/{d}.example.txt", "example.dot" }, .{ "input/{d}.txt", "real.dot" } }) |i| {
        const input_path, const output_path = i;
        blk: {
            var file_path_buf: [64]u8 = undefined;
            const file_path = std.fmt.bufPrint(&file_path_buf, input_path, .{DAY}) catch unreachable;
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
            if (try part2(alloc, input, output_path)) |x| std.debug.print("{s:20} part 2: {d}\n", .{ file_path, x });
        }
    }
}

const Wire = [3]u8;

const GateType = enum { AND, OR, XOR };

const System = struct {
    alloc: Allocator,
    wire_values: std.ArrayListUnmanaged(WireValue),
    wire_names: std.AutoHashMapUnmanaged(Wire, usize),
    gates: std.AutoHashMapUnmanaged(usize, Gate),

    const WireValue = struct {
        name: Wire,
        value: ?bool = null,
    };

    const Self = @This();

    const Gate = struct {
        wires: [2]usize,
        typ: GateType,
    };

    pub fn init(alloc: Allocator) !Self {
        return .{
            .alloc = alloc,
            .wire_values = try std.ArrayListUnmanaged(WireValue).initCapacity(alloc, 1024),
            .wire_names = std.AutoHashMapUnmanaged(Wire, usize){},
            .gates = std.AutoHashMapUnmanaged(usize, Gate){},
        };
    }

    pub fn deinit(self: *Self) void {
        self.wire_values.deinit(self.alloc);
        self.wire_names.deinit(self.alloc);
        self.gates.deinit(self.alloc);
    }

    pub fn addWireWithValueIfNotExists(self: *Self, wire: Wire, value: bool) !usize {
        const id = try self.addEmptyWireIfNotExists(wire);
        self.wire_values.items[id] = .{ .name = wire, .value = value };
        return id;
    }

    fn addEmptyWireIfNotExists(self: *Self, wire: Wire) !usize {
        if (self.wire_names.get(wire)) |id| return id;
        const id = self.wire_values.items.len;
        try self.wire_values.append(self.alloc, .{ .name = wire });
        try self.wire_names.put(self.alloc, wire, id);
        return id;
    }

    pub fn addGate(self: *Self, inputs: [2]Wire, gate_type: GateType, result: Wire) !void {
        const id = try self.addEmptyWireIfNotExists(result);
        const a = try self.addEmptyWireIfNotExists(inputs[0]);
        const b = try self.addEmptyWireIfNotExists(inputs[1]);
        const gate = Gate{ .wires = [_]usize{ a, b }, .typ = gate_type };
        try self.gates.put(self.alloc, id, gate);
    }

    pub fn computeWireByName(self: *Self, wire: Wire) bool {
        const id = self.wire_names.get(wire).?;
        return self.computeWireById(id);
    }

    fn computeWireById(self: *Self, id: usize) bool {
        if (self.wire_values.items[id].value) |value| return value;
        const gate = self.gates.get(id).?;
        const a = self.wire_values.items[gate.wires[0]].value orelse self.computeWireById(gate.wires[0]);
        const b = self.wire_values.items[gate.wires[1]].value orelse self.computeWireById(gate.wires[1]);
        const value = switch (gate.typ) {
            .AND => a and b,
            .OR => a or b,
            .XOR => a != b,
        };
        self.wire_values.items[id].value = value;
        return value;
    }
};

fn lexicographic_less_than(_: void, a: Wire, b: Wire) bool {
    var i: usize = 0;
    while (i < a.len and i < b.len) : (i += 1) {
        if (a[i] < b[i]) return true;
        if (a[i] > b[i]) return false;
    }
    return a.len < b.len;
}

fn part1(alloc: Allocator, input: []const u8) !?u64 {
    var line_iter = std.mem.splitScalar(u8, input, '\n');

    var system = try System.init(alloc);
    defer system.deinit();

    var output_set = std.AutoHashMap(Wire, void).init(alloc);
    defer output_set.deinit();

    while (line_iter.next()) |line| {
        if (line.len == 0) break;
        const wire = line[0..3].*;
        const value = line[5] == '1';
        _ = try system.addWireWithValueIfNotExists(wire, value);
        if (wire[0] == 'z') try output_set.put(wire, {});
    }

    while (line_iter.next()) |line| {
        if (line.len == 0) break;
        var items = std.mem.splitScalar(u8, line, ' ');
        const left_wire: Wire = items.next().?[0..3].*;
        const gate_type = std.meta.stringToEnum(GateType, items.next().?).?;
        const right_wire: Wire = items.next().?[0..3].*;
        _ = items.next().?; // ->
        const out_wire: Wire = items.next().?[0..3].*;
        _ = try system.addGate(.{ left_wire, right_wire }, gate_type, out_wire);
        if (left_wire[0] == 'z') try output_set.put(left_wire, {});
        if (right_wire[0] == 'z') try output_set.put(right_wire, {});
        if (out_wire[0] == 'z') try output_set.put(out_wire, {});
    }

    var output_wires = try std.ArrayList(Wire).initCapacity(alloc, output_set.count());
    defer output_wires.deinit();
    var output_set_iter = output_set.keyIterator();
    while (output_set_iter.next()) |wire| {
        output_wires.appendAssumeCapacity(wire.*);
    }

    std.sort.block(Wire, output_wires.items, {}, lexicographic_less_than);

    var out: u64 = 0;
    for (output_wires.items, 0..) |wire, i| {
        const value = system.computeWireByName(wire);
        out |= @as(u64, @intCast(@intFromBool(value))) << @intCast(i);
    }

    return out;
}

// Outputs the circuit into a graphviz file. To create the image, run `dot -T svg -o real.svg real.dot`.
// cbj,cfk,dmn,gmt,qjj,z07,z18,z35.
fn part2(alloc: Allocator, input: []const u8, output_path: []const u8) !?u64 {
    var line_iter = std.mem.splitScalar(u8, input, '\n');

    var system = try System.init(alloc);
    defer system.deinit();

    var x_set = std.AutoHashMap(Wire, void).init(alloc);
    defer x_set.deinit();
    var y_set = std.AutoHashMap(Wire, void).init(alloc);
    defer y_set.deinit();
    var z_set = std.AutoHashMap(Wire, void).init(alloc);
    defer z_set.deinit();

    while (line_iter.next()) |line| {
        if (line.len == 0) break;
        const wire = line[0..3].*;
        const value = line[5] == '1';
        _ = try system.addWireWithValueIfNotExists(wire, value);
        if (wire[0] == 'z') try z_set.put(wire, {});
    }

    while (line_iter.next()) |line| {
        if (line.len == 0) break;
        var items = std.mem.splitScalar(u8, line, ' ');
        const left_wire: Wire = items.next().?[0..3].*;
        const gate_type = std.meta.stringToEnum(GateType, items.next().?).?;
        const right_wire: Wire = items.next().?[0..3].*;
        _ = items.next().?; // ->
        const out_wire: Wire = items.next().?[0..3].*;
        _ = try system.addGate(.{ left_wire, right_wire }, gate_type, out_wire);
        for ([3]struct { u8, *std.AutoHashMap(Wire, void) }{
            .{ 'x', &x_set },
            .{ 'y', &y_set },
            .{ 'z', &z_set },
        }) |i| {
            const prefix, const set = i;
            if (left_wire[0] == prefix) try set.put(left_wire, {});
            if (right_wire[0] == prefix) try set.put(right_wire, {});
            if (out_wire[0] == prefix) try set.put(out_wire, {});
        }
    }

    var x_wires = try std.ArrayList(Wire).initCapacity(alloc, x_set.count());
    defer x_wires.deinit();
    var y_wires = try std.ArrayList(Wire).initCapacity(alloc, y_set.count());
    defer y_wires.deinit();
    var z_wires = try std.ArrayList(Wire).initCapacity(alloc, z_set.count());
    defer z_wires.deinit();

    for ([3]struct { *std.AutoHashMap(Wire, void), *std.ArrayList(Wire) }{
        .{ &x_set, &x_wires },
        .{ &y_set, &y_wires },
        .{ &z_set, &z_wires },
    }) |i| {
        const set, const wires = i;
        var iter = set.keyIterator();
        while (iter.next()) |wire| wires.appendAssumeCapacity(wire.*);
        std.sort.block(Wire, wires.items, {}, lexicographic_less_than);
    }

    const output = try std.fs.cwd().createFile(output_path, .{});
    defer output.close();
    const writer = output.writer();

    try writer.print("digraph G {{\n", .{});
    try writer.print("    rankdir=TB;\n", .{});

    for (system.wire_values.items) |wire_value| {
        try writer.print("    wire_{s} [label=\"{s}\"];\n", .{ wire_value.name, wire_value.name });
    }
    var gate_iter = system.gates.iterator();
    var gate_idx: usize = 0;
    while (gate_iter.next()) |entry| : (gate_idx += 1) {
        const out_wire_idx = entry.key_ptr.*;
        const gate = entry.value_ptr.*;
        const gate_label = switch (gate.typ) {
            .AND => "AND",
            .OR => "OR",
            .XOR => "XOR",
        };
        try writer.print("    gate_{} [label=\"{s}\"];\n", .{ gate_idx, gate_label });
        try writer.print("    wire_{s} -> gate_{};\n", .{ system.wire_values.items[gate.wires[0]].name, gate_idx });
        try writer.print("    wire_{s} -> gate_{};\n", .{ system.wire_values.items[gate.wires[1]].name, gate_idx });
        try writer.print("    gate_{} -> wire_{s};\n", .{ gate_idx, system.wire_values.items[out_wire_idx].name });
    }

    {
        try writer.print("    subgraph sub_inputs {{\n", .{});
        try writer.print("        rankdir=LR;\n", .{});
        {
            try writer.print("        {{ rank=same", .{});
            for (x_wires.items) |wire| {
                const id = system.wire_names.get(wire) orelse unreachable;
                const wire_value = system.wire_values.items[id];
                try writer.print(" wire_{s}", .{wire_value.name});
            }
            for (y_wires.items) |wire| {
                const id = system.wire_names.get(wire) orelse unreachable;
                const wire_value = system.wire_values.items[id];
                try writer.print(" wire_{s}", .{wire_value.name});
            }
            try writer.print(" }}\n", .{}); // rank=same
        }
        // // Alternative way to display graph
        // {
        //     for (x_wires.items, y_wires.items, 0..) |x_wire, y_wire, i| {
        //         const x_id = system.wire_names.get(x_wire) orelse unreachable;
        //         const y_id = system.wire_names.get(y_wire) orelse unreachable;
        //         const x_wire_value = system.wire_values.items[x_id];
        //         const y_wire_value = system.wire_values.items[y_id];
        //         try stdout.print("        subgraph sub_inputs_{} {{\n", .{i});
        //         try stdout.print("            wire_{s}\n", .{x_wire_value.name});
        //         try stdout.print("            wire_{s}\n", .{y_wire_value.name});
        //         try stdout.print("        }}\n", .{});
        //     }
        // }
        try writer.print("    }}\n", .{}); // subgraph
    }

    {
        try writer.print("    subgraph sub_output {{\n", .{});
        try writer.print("        rankdir=LR;\n", .{});
        try writer.print("        {{ rank=same", .{});
        {
            for (z_wires.items) |wire| {
                const id = system.wire_names.get(wire) orelse unreachable;
                const wire_value = system.wire_values.items[id];
                try writer.print(" wire_{s}", .{wire_value.name});
            }
        }
        try writer.print(" }}\n", .{}); // rank=same
        try writer.print("    }}\n", .{}); // subgraph
    }

    try writer.print("}}", .{});

    return null;
}
