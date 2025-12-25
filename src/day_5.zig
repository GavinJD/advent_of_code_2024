const std = @import("std");
const lib = @import("aoc_2024");

pub fn HashSet(comptime T: type) type {
    return std.AutoHashMap(T, void);
}

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    const input = try lib.read_input(allocator, 5);
    defer allocator.free(input);

    const result = try solve(input, allocator);

    std.log.info("Part 1: {}", .{result.part1});
    std.log.info("Part 2: {}", .{result.part2});
}

fn solve(input: []const u8, allocator: std.mem.Allocator) !struct { part1: u64, part2: u64 } {
    var graph = Graph.init(allocator);
    defer graph.deinit();

    var updates = std.ArrayList(std.ArrayList(u64)).empty;
    defer {
        for (updates.items) |*update| {
            update.clearAndFree(allocator);
        }
        updates.clearAndFree(allocator);
    }

    var lines = std.mem.tokenizeAny(u8, input, "\r\n");
    while (lines.next()) |line| {
        if (std.mem.indexOfScalar(u8, line, '|')) |delim| {
            // parse rule
            const k = try std.fmt.parseInt(u64, line[0..delim], 10);
            const v = try std.fmt.parseInt(u64, line[delim + 1 .. line.len], 10);

            try graph.addEdge(k, v);
        } else {
            // parse updates
            var result = std.ArrayList(u64).empty;

            var tokens = std.mem.splitScalar(u8, line, ',');
            while (tokens.next()) |tok| {
                try result.append(allocator, try std.fmt.parseInt(u64, tok, 10));
            }

            try updates.append(allocator, result);
        }
    }

    var part1: u64 = 0;
    var part2: u64 = 0;
    for (updates.items) |update| {
        // naive approach
        var valid = true;

        var i = update.items.len;
        outer: while (i > 0) {
            i -= 1;

            var j = i;
            while (j > 0) {
                j -= 1;

                if (graph.edgeExists(update.items[i], update.items[j])) {
                    valid = false;
                    break :outer;
                }
            }
        }

        if (valid) {
            part1 += update.items[(update.items.len - 1) / 2];
        } else {
            var subgraph = Graph.init(allocator);
            defer subgraph.deinit();

            for (update.items) |from| {
                try subgraph.addPoint(from);

                for ((graph.adj.get(from) orelse std.ArrayList(u64).empty).items) |to| {
                    if (std.mem.indexOfScalar(u64, update.items, to) != null) {
                        try subgraph.addEdge(from, to);
                    }
                }
            }

            const sorted = try subgraph.topsort();
            defer allocator.free(sorted);

            part2 += sorted[(sorted.len - 1) / 2];
        }
    }

    return .{ .part1 = part1, .part2 = part2 };
}

pub const Graph = struct {
    allocator: std.mem.Allocator,
    adj: std.AutoHashMap(u64, std.ArrayList(u64)),

    pub fn init(allocator: std.mem.Allocator) Graph {
        const adj = std.AutoHashMap(u64, std.ArrayList(u64)).init(allocator);
        return .{ .adj = adj, .allocator = allocator };
    }

    pub fn deinit(self: *Graph) void {
        var vals = self.adj.valueIterator();
        while (vals.next()) |val| {
            val.deinit(self.allocator);
        }
        self.adj.deinit();
    }

    pub fn addPoint(self: *Graph, p: u64) !void {
        _ = try self.adj.getOrPutValue(p, std.ArrayList(u64).empty);
    }

    pub fn addEdge(self: *Graph, from: u64, to: u64) !void {
        const entry = try self.adj.getOrPut(from);
        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayList(u64).empty;
        }

        try entry.value_ptr.*.append(self.allocator, to);
    }

    pub fn edgeExists(self: *const Graph, from: u64, to: u64) bool {
        const entry = self.adj.get(from) orelse return false;
        return std.mem.indexOfScalar(u64, entry.items, to) != null;
    }

    pub fn topsort(self: *const Graph) ![]u64 {
        var result = try self.allocator.alloc(u64, self.adj.count());
        var resultIdx: usize = 0;
        const allocator = self.allocator;

        var indegree = std.AutoHashMap(u64, u64).init(allocator);
        defer indegree.deinit();

        {
            var iter = self.adj.iterator();
            while (iter.next()) |e| {
                const k = e.key_ptr.*;
                const v = e.value_ptr.*;

                _ = try indegree.getOrPutValue(k, 0);

                for (v.items) |vi| {
                    (try indegree.getOrPutValue(vi, 0)).value_ptr.* += 1;
                }
            }
        }

        var queue = try std.ArrayList(u64).initCapacity(allocator, self.adj.count());
        defer queue.deinit(allocator);
        // initialize queue
        {
            var iter = indegree.iterator();
            while (iter.next()) |e| {
                if (e.value_ptr.* == 0) queue.appendAssumeCapacity(e.key_ptr.*);
            }
        }

        while (queue.items.len > 0) {
            const next = queue.orderedRemove(0);
            result[resultIdx] = next;
            resultIdx += 1;

            for (self.adj.get(next).?.items) |j| {
                const out_entry = indegree.getEntry(j).?;
                out_entry.value_ptr.* -= 1;

                if (out_entry.value_ptr.* == 0) {
                    queue.appendAssumeCapacity(j);
                }
            }
        }

        return result;
    }
};

test "example input" {
    const input =
        \\47|53
        \\97|13
        \\97|61
        \\97|47
        \\75|29
        \\61|13
        \\75|53
        \\29|13
        \\97|29
        \\53|29
        \\61|53
        \\97|53
        \\61|29
        \\47|13
        \\75|47
        \\97|75
        \\47|61
        \\75|61
        \\47|29
        \\75|13
        \\53|13
        \\
        \\75,47,61,53,29
        \\97,61,53,29,13
        \\75,29,13
        \\75,97,47,61,53
        \\61,13,29
        \\97,13,75,29,47
    ;
    const result = try solve(input, std.testing.allocator);

    try std.testing.expectEqual(143, result.part1);
    try std.testing.expectEqual(123, result.part2);
}
