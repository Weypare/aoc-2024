const std = @import("std");
const Allocator = std.mem.Allocator;

const DAY = 23;

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

const Node = [2]u8;

const Graph = struct {
    alloc: Allocator,
    nodes: std.ArrayListUnmanaged(Node),
    node_ids: std.AutoHashMapUnmanaged(Node, usize),
    adjacency_lists: std.ArrayListUnmanaged(std.ArrayListUnmanaged(usize)),

    const Self = @This();

    pub fn init(alloc: Allocator) !Self {
        return .{
            .alloc = alloc,
            .nodes = try std.ArrayListUnmanaged(Node).initCapacity(alloc, 1024),
            .node_ids = std.AutoHashMapUnmanaged(Node, usize){},
            .adjacency_lists = try std.ArrayListUnmanaged(std.ArrayListUnmanaged(usize)).initCapacity(alloc, 1024),
        };
    }

    pub fn deinit(self: *Self) void {
        self.nodes.deinit(self.alloc);
        self.node_ids.deinit(self.alloc);
        for (self.adjacency_lists.items) |*adjacency_list| {
            adjacency_list.deinit(self.alloc);
        }
        self.adjacency_lists.deinit(self.alloc);
    }

    pub fn addNodeIfAbsent(self: *Self, node: Node) !usize {
        if (self.node_ids.get(node)) |id| return id;
        const id = self.nodes.items.len;
        try self.nodes.append(self.alloc, node);
        try self.node_ids.put(self.alloc, node, id);
        return id;
    }

    pub fn addEdge(self: *Self, a: Node, b: Node) !void {
        const a_id = try self.addNodeIfAbsent(a);
        const b_id = try self.addNodeIfAbsent(b);
        var a_adjacency_list = try self.adjacencyArrayListFor(a_id);
        try a_adjacency_list.append(self.alloc, b_id);
        var b_adjacency_list = try self.adjacencyArrayListFor(b_id);
        try b_adjacency_list.append(self.alloc, a_id);
    }

    fn adjacencyArrayListFor(self: *Self, id: usize) !*std.ArrayListUnmanaged(usize) {
        while (self.adjacency_lists.items.len <= id) {
            const list = try std.ArrayListUnmanaged(usize).initCapacity(self.alloc, 128);
            try self.adjacency_lists.append(self.alloc, list);
        }
        return &self.adjacency_lists.items[id];
    }
};

fn part1(alloc: Allocator, input: []const u8) !?u64 {
    var line_iter = std.mem.splitScalar(u8, input, '\n');

    var graph = try Graph.init(alloc);
    defer graph.deinit();

    while (line_iter.next()) |line| {
        if (line.len == 0) continue;
        const a = line[0..2].*;
        const b = line[3..5].*;
        try graph.addEdge(a, b);
    }

    var triples = std.AutoHashMap([3]usize, void).init(alloc);
    defer triples.deinit();
    for (graph.adjacency_lists.items, 0..) |first_adj_list, first| {
        if (graph.nodes.items[first][0] != 't') continue;
        for (first_adj_list.items) |second| {
            const second_adj_list = &graph.adjacency_lists.items[second];
            for (second_adj_list.items) |third| {
                if (third == first) continue;
                var triple = [3]usize{ first, second, third };
                std.sort.insertion(usize, &triple, {}, std.sort.asc(usize));
                for (first_adj_list.items) |item| {
                    if (third == item) {
                        try triples.put(triple, {});
                        break;
                    }
                }
            }
        }
    }

    return triples.count();
}

const NodeSet = std.AutoHashMap(usize, void);

// https://en.wikipedia.org/wiki/Bron%E2%80%93Kerbosch_algorithm#With_pivoting
fn BronKerbosch2(graph: *const Graph, R: *NodeSet, P: *NodeSet, X: *NodeSet, out: *std.ArrayList(NodeSet)) !void {
    if (P.count() == 0 and X.count() == 0) {
        try out.append(try R.clone());
        return;
    }
    const u = if (P.count() > 0) blk: {
        var iter = P.keyIterator();
        break :blk iter.next().?.*;
    } else blk: {
        var iter = X.keyIterator();
        break :blk iter.next().?.*;
    };
    const u_adj_list = &graph.adjacency_lists.items[u];

    var P_without_u_neigbors = try P.clone();
    defer P_without_u_neigbors.deinit();
    for (u_adj_list.items) |v| _ = P_without_u_neigbors.remove(v);

    while (P_without_u_neigbors.count() > 0) {
        const v = blk: {
            var iter = P_without_u_neigbors.keyIterator();
            break :blk iter.next().?.*;
        };

        var R_with_v = try R.clone();
        defer R_with_v.deinit();
        try R_with_v.put(v, {});

        var P_only_v_neigbors = try P.clone();
        defer P_only_v_neigbors.deinit();
        {
            const v_adj_list = &graph.adjacency_lists.items[v];
            var P_iter = P.keyIterator();
            while (P_iter.next()) |w| {
                const contains = std.mem.indexOfScalar(usize, v_adj_list.items, w.*) != null;
                if (!contains) _ = P_only_v_neigbors.remove(w.*);
            }
        }

        var X_only_v_neigbors = try X.clone();
        defer X_only_v_neigbors.deinit();
        {
            const v_adj_list = &graph.adjacency_lists.items[v];
            var X_iter = X.keyIterator();
            while (X_iter.next()) |w| {
                const contains = std.mem.indexOfScalar(usize, v_adj_list.items, w.*) != null;
                if (!contains) _ = X_only_v_neigbors.remove(w.*);
            }
        }

        BronKerbosch2(graph, &R_with_v, &P_only_v_neigbors, &X_only_v_neigbors, out) catch unreachable;
        _ = P.remove(v);
        _ = P_without_u_neigbors.remove(v);
        try X.put(v, {});
    }
}

fn lexicographic_less_than(_: void, a: Node, b: Node) bool {
    var i: usize = 0;
    while (i < a.len and i < b.len) : (i += 1) {
        if (a[i] < b[i]) return true;
        if (a[i] > b[i]) return false;
    }
    return a.len < b.len;
}

fn part2(alloc: Allocator, input: []const u8) !?u64 {
    var line_iter = std.mem.splitScalar(u8, input, '\n');

    var graph = try Graph.init(alloc);
    defer graph.deinit();

    while (line_iter.next()) |line| {
        if (line.len == 0) continue;
        const a = line[0..2].*;
        const b = line[3..5].*;
        try graph.addEdge(a, b);
    }

    var R = NodeSet.init(alloc);
    defer R.deinit();
    var P = NodeSet.init(alloc);
    defer P.deinit();
    for (0..graph.nodes.items.len) |i| try P.put(i, {});
    var X = NodeSet.init(alloc);
    defer X.deinit();

    var out = std.ArrayList(NodeSet).init(alloc);
    defer out.deinit();
    defer for (out.items) |*set| set.deinit();

    try BronKerbosch2(&graph, &R, &P, &X, &out);

    var max_set_idx: usize = undefined;
    var max_count: usize = 0;
    for (out.items, 0..) |set, set_idx| {
        if (set.count() > max_count) {
            max_count = set.count();
            max_set_idx = set_idx;
        }
    }

    const max_set = &out.items[max_set_idx];
    var max_set_nodes = try std.ArrayList(Node).initCapacity(alloc, max_set.count());
    defer max_set_nodes.deinit();
    var max_set_iter = max_set.keyIterator();
    while (max_set_iter.next()) |node| {
        max_set_nodes.appendAssumeCapacity(graph.nodes.items[node.*]);
    }

    std.sort.block(Node, max_set_nodes.items, {}, lexicographic_less_than);

    for (max_set_nodes.items, 0..) |node, i| {
        if (i > 0) std.debug.print(",", .{});
        std.debug.print("{s}", .{node});
    }
    std.debug.print("\n", .{});

    return null;
}
