const std = @import("std");
const lib = @import("aoc_2024");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    const input = try lib.read_input(allocator, 4);
    defer allocator.free(input);

    const result = solve(input, "\r\n", allocator);

    std.log.info("Part 1: {}", .{result.part1});
    std.log.info("Part 2: {}", .{result.part2});
}

fn solve(input: []const u8, delim: []const u8, allocator: std.mem.Allocator) struct { part1: u64, part2: u64 } {
    _ = allocator;

    const grid = lib.Grid.init(input, delim);

    var xmas_count: u64 = 0;
    for (0..grid.columns) |x_u| {
        for (0..grid.rows) |y_u| {
            const x: i64 = @intCast(x_u);
            const y: i64 = @intCast(y_u);
            const char = grid.get(x, y).?;

            if (char == 'X') {
                for (lib.GRID_DIR) |dir| {
                    var matched = true;
                    for ("MAS", 1..) |wanted, i_u| {
                        const i: i64 = @intCast(i_u);
                        const got = grid.get(x + dir[0] * i, y + dir[1] * i) orelse {
                            matched = false;
                            break;
                        };

                        if (wanted != got) {
                            matched = false;
                            break;
                        }
                    }

                    if (matched) xmas_count += 1;
                }
            }
        }
    }

    var mas_x_count: u64 = 0;
    for (0..grid.columns) |xu| {
        for (0..grid.rows) |yu| {
            const x: i64 = @intCast(xu);
            const y: i64 = @intCast(yu);
            const char = grid.get(x, y).?;

            if (char == 'A') {
                const tl = grid.get(x - 1, y - 1) orelse continue;
                const tr = grid.get(x + 1, y - 1) orelse continue;
                const bl = grid.get(x - 1, y + 1) orelse continue;
                const br = grid.get(x + 1, y + 1) orelse continue;

                if (((tl == 'M' and br == 'S') or (tl == 'S' and br == 'M')) and ((tr == 'M' and bl == 'S') or (tr == 'S' and bl == 'M')))
                    mas_x_count += 1;
            }
        }
    }

    return .{ .part1 = xmas_count, .part2 = mas_x_count };
}

test "example input" {
    const input =
        \\MMMSXXMASM
        \\MSAMXMSMSA
        \\AMXSXMAAMM
        \\MSAMASMSMX
        \\XMASAMXAMM
        \\XXAMMXXAMA
        \\SMSMSASXSS
        \\SAXAMASAAA
        \\MAMMMXMMMM
        \\MXMXAXMASX
    ;

    const result = solve(input, "\n", std.testing.allocator);
    try std.testing.expectEqual(18, result.part1);
    try std.testing.expectEqual(9, result.part2);
}
