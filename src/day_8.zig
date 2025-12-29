const std = @import("std");
const lib = @import("aoc_2024");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    const input = try lib.read_input(allocator, 8);
    defer allocator.free(input);

    const result = try solve(input, "\r\n", allocator);

    std.log.info("Part 1: {}", .{result.part1});
    std.log.info("Part 2: {}", .{result.part2});
}

fn solve(input: []const u8, delim: []const u8, allocator: std.mem.Allocator) !lib.Solution {
    const grid = lib.Grid.init(input, delim);
    var antinodes = try getAntinodes(grid, allocator);
    defer antinodes.simple.clearAndFree();
    defer antinodes.full.clearAndFree();

    return .{ .part1 = antinodes.simple.count(), .part2 = antinodes.full.count() };
}

const AntiNodes = struct {
    simple: lib.HashSet([2]i64),
    full: lib.HashSet([2]i64),
};

fn getAntinodes(grid: lib.Grid, allocator: std.mem.Allocator) !AntiNodes {
    var antennas = std.AutoHashMap(u8, std.ArrayList([2]f64)).init(allocator);
    defer {
        var vals = antennas.valueIterator();
        while (vals.next()) |val| : (val.clearAndFree(allocator)) {}
        antennas.clearAndFree();
    }

    for (0..grid.rows) |y| {
        for (0..grid.columns) |x| {
            if (grid.get(@intCast(x), @intCast(y))) |point| {
                if (point == '.') continue;

                const entry = try antennas.getOrPut(point);
                if (!entry.found_existing) entry.value_ptr.* = std.ArrayList([2]f64).empty;

                try entry.value_ptr.append(allocator, .{ @floatFromInt(x), @floatFromInt(y) });
            }
        }
    }

    // std.debug.print("Finished getting antennas, total: {}\n", .{antennas.count()});

    var simple_antinodes = lib.HashSet([2]i64).init(allocator);
    var full_antinodes = lib.HashSet([2]i64).init(allocator);
    var entries = antennas.iterator();
    while (entries.next()) |entry| {
        const positions = entry.value_ptr;

        // std.debug.print("For Antenna=({c}), found positions=({any})\n", .{ entry.key_ptr.*, positions.items });

        for (0..positions.items.len) |i| {
            for (i + 1..positions.items.len) |j| {
                const p1 = positions.items[i];
                const p2 = positions.items[j];
                // std.debug.print("=> p1: {any}, p2: {any}\n", .{ p1, p2 });

                // SIMPLE
                const left: [2]f64 = .{ p1[0] + p1[0] - p2[0], p1[1] + p1[1] - p2[1] };
                const right: [2]f64 = .{ p2[0] - p1[0] + p2[0], p2[1] - p1[1] + p2[1] };

                if (isWholeNumber(left[0]) and isWholeNumber(left[1]) and grid.get(@intFromFloat(left[0]), @intFromFloat(left[1])) != null) {
                    try simple_antinodes.put(.{ @intFromFloat(left[0]), @intFromFloat(left[1]) }, {});
                }
                if (isWholeNumber(right[0]) and isWholeNumber(right[1]) and grid.get(@intFromFloat(right[0]), @intFromFloat(right[1])) != null) {
                    try simple_antinodes.put(.{ @intFromFloat(right[0]), @intFromFloat(right[1]) }, {});
                }

                // FULL
                const m = (p1[1] - p2[1]) / (p1[0] - p2[0]);
                // std.debug.print("For {any}, {any}, slope = {}\n", .{ p1, p2, m });
                const c = p1[1] - m * p1[0];

                for (0..grid.rows) |y| {
                    for (0..grid.columns) |x| {
                        const y_calc = m * @as(f64, @floatFromInt(x)) + c;
                        if (@abs(y_calc - @as(f64, @floatFromInt(y))) <= EPSILON) {
                            try full_antinodes.put(.{ @intCast(x), @intCast(y) }, {});
                        }
                    }
                }
                // For some reason this didnt work (ﾉ*･ω･)ﾉ
                // for (0..grid.columns) |x| {
                //     const y = m * @as(f64, @floatFromInt(x)) + c;
                //     if (isWholeNumber(y) and grid.get(@intCast(x), @intFromFloat(y)) != null) {
                //         try full_antinodes.put(.{ @intCast(x), @intFromFloat(y) }, {});
                //     }
                // }
                // for (0..grid.rows) |y| {
                //     const x = (@as(f64, @floatFromInt(y)) - c) / m;
                //     if (isWholeNumber(x) and grid.get(@intFromFloat(x), @intCast(y)) != null) {
                //         try full_antinodes.put(.{ @intFromFloat(x), @intCast(y) }, {});
                //     }
                // }
            }
        }
    }

    return .{ .simple = simple_antinodes, .full = full_antinodes };
}

const EPSILON: f64 = std.math.pow(f64, 10, -5);
fn isWholeNumber(x: f64) bool {
    const epsilon_res = @abs(x - @trunc(x)) <= EPSILON;
    // const previous_res = @trunc(x) == x;

    // if (previous_res != epsilon_res) {
    //     std.debug.print("Epsilon({}) special case: {}\n", .{ EPSILON, x });
    // }
    return epsilon_res;
}

test "basic resonance" {
    const input =
        \\..........
        \\..........
        \\..........
        \\....a.....
        \\..........
        \\.....a....
        \\..........
        \\..........
        \\..........
        \\..........
    ;

    var antinodes = try getAntinodes(lib.Grid.init(input, "\n"), std.testing.allocator);
    defer antinodes.simple.clearAndFree();
    defer antinodes.full.clearAndFree();

    try std.testing.expectEqual(2, antinodes.simple.count());
    try std.testing.expect(antinodes.simple.contains([2]i64{ 3, 1 }));
    try std.testing.expect(antinodes.simple.contains([2]i64{ 6, 7 }));
}

test "advanced resonance" {
    const input =
        \\T.........
        \\...T......
        \\.T........
        \\..........
        \\..........
        \\..........
        \\..........
        \\..........
        \\..........
        \\..........
    ;

    var antinodes = try getAntinodes(lib.Grid.init(input, "\n"), std.testing.allocator);
    defer antinodes.simple.clearAndFree();
    defer antinodes.full.clearAndFree();

    try std.testing.expectEqual(9, antinodes.full.count());
    try std.testing.expect(antinodes.full.contains([2]i64{ 0, 0 }));
}

test "advanced resonance 2" {
    const input =
        \\T.........
        \\..........
        \\.T........
        \\..........
        \\..T.......
        \\..........
        \\..........
        \\..........
        \\..........
        \\..........
    ;

    var antinodes = try getAntinodes(lib.Grid.init(input, "\n"), std.testing.allocator);
    defer antinodes.simple.clearAndFree();
    defer antinodes.full.clearAndFree();

    try std.testing.expectEqual(5, antinodes.full.count());
}

test "example input" {
    const input =
        \\............
        \\........0...
        \\.....0......
        \\.......0....
        \\....0.......
        \\......A.....
        \\............
        \\............
        \\........A...
        \\.........A..
        \\............
        \\............
    ;
    const res = try solve(input, "\n", std.testing.allocator);

    try std.testing.expectEqual(14, res.part1);
    try std.testing.expectEqual(34, res.part2);
}
