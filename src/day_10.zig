const std = @import("std");
const lib = @import("aoc_2024");

pub fn HashSet(comptime T: type) type {
    return std.AutoHashMap(T, void);
}

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    const input = try lib.read_input(allocator, 10);
    defer allocator.free(input);

    const result = try solve(input, "\r\n", allocator);

    std.log.info("Part 1: {}", .{result.part1});
    std.log.info("Part 2: {}", .{result.part2});
}

fn solve(input: []const u8, delim: []const u8, allocator: std.mem.Allocator) !lib.Solution {
    const grid = lib.Grid.init(input, delim);

    var trailheads = try grid.findAllPosEqualTo('0', allocator);
    defer trailheads.deinit(allocator);

    const visited = try allocator.alloc(bool, grid.rows * grid.columns);
    defer allocator.free(visited);
    @memset(visited, false);

    var part1: u64 = 0;
    for (trailheads.items) |trailhead| {
        defer @memset(visited, false);

        try floodfill(&grid, trailhead, visited, allocator);

        for (0..grid.rows) |y| {
            for (0..grid.columns) |x| {
                const idx = x + y * grid.columns;
                if (visited[idx] and grid.get(@intCast(x), @intCast(y)) == '9') {
                    part1 += 1;
                }
            }
        }
    }

    var part2: u64 = 0;
    var paths = lib.HashSet([10][2]i64).init(allocator);
    defer paths.deinit();

    for (trailheads.items) |trailhead| {
        defer paths.clearRetainingCapacity();

        var so_far: [10][2]i64 = .{
            .{ 0, 0 },
            .{ 0, 0 },
            .{ 0, 0 },
            .{ 0, 0 },
            .{ 0, 0 },
            .{ 0, 0 },
            .{ 0, 0 },
            .{ 0, 0 },
            .{ 0, 0 },
            .{ 0, 0 },
        };
        so_far[0] = trailhead;

        try recordPaths(&grid, trailhead, &so_far, 1, &paths, allocator);

        part2 += paths.count();
    }

    return .{ .part1 = part1, .part2 = part2 };
}

const VALID_DIR: [4][2]i64 = .{
    .{ 0, 1 },
    .{ 0, -1 },
    .{ 1, 0 },
    .{ -1, 0 },
};

fn floodfill(grid: *const lib.Grid, start: [2]i64, visited: []bool, allocator: std.mem.Allocator) !void {
    var queue = std.ArrayList([2]i64).empty;
    defer queue.deinit(allocator);

    try queue.append(allocator, start);

    while (queue.items.len > 0) {
        const curr = queue.orderedRemove(0);
        const curr_val = grid.get(curr[0], curr[1]).?;

        const x: usize = @intCast(curr[0]);
        const y: usize = @intCast(curr[1]);
        visited[x + y * grid.columns] = true;

        for (VALID_DIR) |dir| {
            const next: [2]i64 = .{
                curr[0] + dir[0],
                curr[1] + dir[1],
            };
            if (grid.get(next[0], next[1])) |next_val| {
                const nx: usize = @intCast(next[0]);
                const ny: usize = @intCast(next[1]);
                if (!visited[nx + ny * grid.columns] and next_val > curr_val and next_val - curr_val == 1) {
                    try queue.append(allocator, next);
                }
            }
        }
    }
}

fn recordPaths(grid: *const lib.Grid, curr: [2]i64, so_far: *[10][2]i64, so_far_len: usize, paths: *lib.HashSet([10][2]i64), allocator: std.mem.Allocator) !void {
    if (so_far_len == 10) {
        const copy: [10][2]i64 = so_far.*;
        try paths.put(copy, {});
    }

    const curr_val = grid.get(curr[0], curr[1]).?;
    for (VALID_DIR) |dir| {
        const next: [2]i64 = .{
            curr[0] + dir[0],
            curr[1] + dir[1],
        };
        if (grid.get(next[0], next[1])) |next_val| {
            if (next_val > curr_val and next_val - curr_val == 1) {
                so_far[so_far_len] = next;
                try recordPaths(grid, next, so_far, so_far_len + 1, paths, allocator);
            }
        }
    }
}

test "example input" {
    const input =
        \\89010123
        \\78121874
        \\87430965
        \\96549874
        \\45678903
        \\32019012
        \\01329801
        \\10456732
    ;
    const res = try solve(input, "\n", std.testing.allocator);

    try std.testing.expectEqual(36, res.part1);
    try std.testing.expectEqual(81, res.part2);
}
