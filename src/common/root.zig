//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

pub fn read_input(allocator: std.mem.Allocator, day: u8) ![]const u8 {
    const path = try std.fmt.allocPrint(allocator, "inputs/day_{}.txt", .{day});
    defer allocator.free(path);

    const input_file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    defer input_file.close();

    const file_size = try input_file.getEndPos();
    const buf: []u8 = try allocator.alloc(u8, file_size);

    _ = try input_file.readAll(buf);

    return buf;
}

pub const Solution = struct { part1: u64, part2: u64 };

// ====== PARSING ========
pub fn parseNum(input: []const u8, index: *usize) !u64 {
    const start = index.*;

    while (index.* < input.len and std.ascii.isDigit(input[index.*])) {
        index.* += 1;
    }

    if (start == index.*) {
        return error.InvalidDigit;
    } else {
        return try std.fmt.parseInt(u64, input[start..index.*], 10);
    }
}

pub fn parseExact(input: []const u8, to_parse: []const u8, index: *usize) !void {
    if (input.len - index.* - 1 < to_parse.len) return error.ReachedEnd;

    for (to_parse, 0..) |rc, j| {
        if (input[index.* + j] != rc) return error.NotMatching;
    }

    index.* += to_parse.len;
}

// ====== GRID ==========
// TODO: Move to separate file

pub const GRID_DIR: [8][2]i64 = .{ .{ -1, -1 }, .{ -1, 0 }, .{ -1, 1 }, .{ 0, -1 }, .{ 0, 1 }, .{ 1, -1 }, .{ 1, 0 }, .{ 1, 1 } };

pub const Grid = struct {
    data: []const u8,
    delim: []const u8,
    rows: usize,
    columns: usize,

    pub fn init(input: []const u8, delim: []const u8) @This() {
        std.debug.assert(delim.len > 0);
        const columns = std.mem.indexOfScalarPos(u8, input, 0, delim[0]).?;
        var rows = std.mem.count(u8, input, delim);
        if (!std.mem.eql(u8, input[input.len - delim.len ..], delim)) {
            rows += 1;
        }

        return Grid{
            .data = input,
            .delim = delim,
            .rows = rows,
            .columns = columns,
        };
    }

    pub fn get(self: *const Grid, x: i64, y: i64) ?u8 {
        if (x < 0 or x >= self.columns) return null;
        if (y < 0 or y >= self.rows) return null;

        return self.data[@as(usize, @intCast(x)) + (@as(usize, @intCast(y)) * (self.columns + self.delim.len))];
    }

    pub fn findFirstPos(self: *const Grid, vals: []const u8) ?[2]i64 {
        for (0..self.rows) |y| {
            const start = y * (self.columns + self.delim.len);
            if (std.mem.indexOfAny(u8, self.data[start..][0..self.columns], vals)) |x| {
                return .{ @intCast(x), @intCast(y) };
            }
        }

        return null;
    }
};

test "grid constructor normal" {
    const input = "ABCD\r\nPQRS\r\nLMNO\r\nWXYZ";
    const grid = Grid.init(input, "\r\n");

    try std.testing.expectEqual(4, grid.rows);
    try std.testing.expectEqual(4, grid.columns);
}

test "grid constructor with trailing delimiter" {
    const input = "ABC\r\nPQR\r\nLMN\r\nXYZ\r\n";
    const grid = Grid.init(input, "\r\n");

    try std.testing.expectEqual(4, grid.rows);
    try std.testing.expectEqual(3, grid.columns);
}

test "grid getter" {
    const input = "ABC\r\nPQR\r\nLMN\r\nXYZ\r\n";
    const grid = Grid.init(input, "\r\n");

    try std.testing.expectEqual('A', grid.get(0, 0));
    try std.testing.expectEqual('B', grid.get(1, 0));
    try std.testing.expectEqual('C', grid.get(2, 0));
    try std.testing.expectEqual('P', grid.get(0, 1));
    try std.testing.expectEqual('Q', grid.get(1, 1));
    try std.testing.expectEqual('R', grid.get(2, 1));

    try std.testing.expectEqual(null, grid.get(99, 99));
}

test "grid getter 2" {
    const input =
        \\01
        \\23
        \\45
        \\67
        \\89
    ;
    const grid = Grid.init(input, "\n");

    try std.testing.expectEqual('2', grid.get(0, 1));
    try std.testing.expectEqual('4', grid.get(0, 2));
    try std.testing.expectEqual('5', grid.get(1, 2));
    try std.testing.expectEqual(null, grid.get(2, 2));
}

test "iterate all" {
    const input =
        \\01
        \\23
        \\45
        \\67
        \\89
    ;
    const grid = Grid.init(input, "\n");

    for (0..grid.columns) |xu| {
        for (0..grid.rows) |yu| {
            const x: i64 = @intCast(xu);
            const y: i64 = @intCast(yu);
            try std.testing.expectEqual(@as(u8, @intCast(xu + yu * grid.columns)) + '0', grid.get(x, y));
        }
    }
}
