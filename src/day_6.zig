const std = @import("std");
const lib = @import("aoc_2024");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    const input = try lib.read_input(allocator, 6);
    defer allocator.free(input);

    const result = try solve(input, "\r\n", allocator);

    std.log.info("Part 1: {}", .{result.part1});
    std.log.info("Part 2: {}", .{result.part2});
}

const Direction = enum {
    up,
    down,
    left,
    right,
    pub fn rotateClockwise(self: *const Direction) Direction {
        return switch (self.*) {
            Direction.right => Direction.down,
            Direction.down => Direction.left,
            Direction.left => Direction.up,
            Direction.up => Direction.right,
        };
    }
};

const Path = struct {
    data: [][4]bool,
    rows: usize,
    columns: usize,

    pub fn init(grid: *const lib.Grid, allocator: std.mem.Allocator) !Path {
        const data = try allocator.alloc([4]bool, grid.rows * grid.columns);
        @memset(data, .{false} ** 4);

        return .{ .rows = grid.rows, .columns = grid.columns, .data = data };
    }

    pub fn copy(other: *const Path, allocator: std.mem.Allocator) !Path {
        const data = try allocator.alloc([4]bool, other.rows * other.columns);
        @memcpy(data, other.data);

        return .{ .rows = other.rows, .columns = other.columns, .data = data };
    }

    pub fn stepOn(self: *Path, x: i64, y: i64, dir: Direction) void {
        if (x < 0 or x >= self.columns) return;
        if (y < 0 or y >= self.rows) return;

        const visitIdx: usize = @as(usize, @intCast(x)) + @as(usize, @intCast(y)) * self.columns;
        self.data[visitIdx][@intFromEnum(dir)] = true;
    }

    pub fn canPlaceObstacle(self: *const Path, grid: *const lib.Grid, x: i64, y: i64) bool {
        if (x < 0 or x >= self.columns) return false;
        if (y < 0 or y >= self.rows) return false;

        if (grid.get(x, y) == '#') return false;

        // IMPORTANT: We must never have previously stepped on this point in any direction, to place an obstacle there.
        //            Because if we had previously stepped there, we would've run into the obstacle there before.
        // thank you reddit
        const visitIdx: usize = @as(usize, @intCast(x)) + @as(usize, @intCast(y)) * self.columns;
        return !self.data[visitIdx][0] and !self.data[visitIdx][1] and !self.data[visitIdx][2] and !self.data[visitIdx][3];
    }

    pub fn previouslySteppedOn(self: *const Path, x: i64, y: i64, dir: Direction) bool {
        if (x < 0 or x > self.columns) return false;
        if (y < 0 or y > self.rows) return false;

        const visitIdx: usize = @as(usize, @intCast(x)) + @as(usize, @intCast(y)) * self.columns;
        return self.data[visitIdx][@intFromEnum(dir)];
    }

    pub fn deinit(self: *Path, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }

    pub fn eql(self: *const Path, other: *const Path) bool {
        if (self.rows != other.rows or self.columns != other.columns) return false;

        for (self.data, other.data) |self_row, other_row| {
            if (!std.mem.eql(bool, &self_row, &other_row)) return false;
        }

        return true;
    }

    pub fn hash(self: *const Path, hasher: *std.hash.Wyhash) void {
        hasher.update(std.mem.asBytes(&self.rows));
        hasher.update(std.mem.asBytes(&self.columns));

        for (self.data) |point| {
            for (point) |p| {
                hasher.update(&[_]u8{@intFromBool(p)});
            }
        }
    }
};

const DIR: [4][2]i64 = .{
    .{ 0, -1 },
    .{ 0, 1 },
    .{ -1, 0 },
    .{ 1, 0 },
};
const DIR_REPR: *const [4]u8 = "^v<>";

fn solve(input: []const u8, delim: []const u8, allocator: std.mem.Allocator) !struct { part1: u64, part2: u64 } {
    var grid = lib.Grid.init(input, delim);

    var visited = try allocator.alloc(bool, grid.rows * grid.columns);
    defer allocator.free(visited);
    @memset(visited, false);

    var path = try Path.init(&grid, allocator);
    defer path.deinit(allocator);

    // hash all new obstacles?
    var obstacles = std.HashMap([2]i64, void, struct {
        pub fn hash(_: @This(), p: [2]i64) u64 {
            var h = std.hash.Wyhash.init(0);
            std.hash.autoHash(&h, p);
            return h.final();
        }
        pub fn eql(_: @This(), this: [2]i64, that: [2]i64) bool {
            return std.mem.eql(i64, &this, &that);
        }
    }, std.hash_map.default_max_load_percentage).init(allocator);
    defer obstacles.clearAndFree();

    var guard_pos = grid.findFirstPos(DIR_REPR).?;
    const first_guard_val = grid.get(guard_pos[0], guard_pos[1]).?;
    var guard_dir: Direction = @enumFromInt(std.mem.indexOfScalar(u8, DIR_REPR, first_guard_val).?);
    while (grid.get(guard_pos[0], guard_pos[1])) |_| {
        const next_pos: [2]i64 = .{
            guard_pos[0] + DIR[@intFromEnum(guard_dir)][0],
            guard_pos[1] + DIR[@intFromEnum(guard_dir)][1],
        };

        if (path.canPlaceObstacle(&grid, next_pos[0], next_pos[1])) {
            var path_copy = try path.copy(allocator);
            defer path_copy.deinit(allocator);

            if (endsInLoop(&grid, guard_pos, guard_dir, &path_copy, next_pos)) {
                try obstacles.put(next_pos, {});
            }
        }

        const visit_idx = @as(usize, @intCast(guard_pos[0])) + @as(usize, @intCast(guard_pos[1])) * grid.columns;
        visited[visit_idx] = true;
        path.stepOn(guard_pos[0], guard_pos[1], guard_dir);

        // obstacle found
        if (grid.get(next_pos[0], next_pos[1]) == '#') {
            guard_dir = guard_dir.rotateClockwise();
        } else {
            guard_pos = next_pos;
        }
    }

    var part1: u64 = 0;
    for (visited) |v| {
        if (v) part1 += 1;
    }
    const part2 = obstacles.count();
    return .{
        .part1 = part1,
        .part2 = part2,
    };
}

fn debugPrintPath(grid: *const lib.Grid, path: *const Path, extra_obstacle: [2]i64) void {
    for (0..grid.rows) |y| {
        for (0..grid.rows) |x| {
            const selected = path.data[x + y * grid.columns];
            const selected_count: u64 =
                @as(u64, @intCast(@intFromBool(selected[0]))) +
                @as(u64, @intCast(@intFromBool(selected[1]))) +
                @as(u64, @intCast(@intFromBool(selected[2]))) +
                @as(u64, @intCast(@intFromBool(selected[3])));

            const xi: i64 = @intCast(x);
            const yi: i64 = @intCast(y);
            if (grid.get(xi, yi)) |curr| {
                switch (curr) {
                    '#' => std.debug.print("#", .{}),
                    '.' => {
                        if (extra_obstacle[0] == xi and extra_obstacle[1] == yi) {
                            std.debug.print("O", .{});
                        } else if (selected_count == 0) {
                            std.debug.print(".", .{});
                        } else if (selected_count > 1) {
                            std.debug.print("+", .{});
                        } else if (selected[0] or selected[1]) {
                            std.debug.print("|", .{});
                        } else {
                            std.debug.print("-", .{});
                        }
                    },
                    else => std.debug.print("{c}", .{curr}),
                }
            }
        }
        std.debug.print("\n", .{});
    }
}

fn endsInLoop(grid: *const lib.Grid, start_pos: [2]i64, start_dir: Direction, path: *Path, new_obstacle: [2]i64) bool {
    var pos = start_pos;
    var dir = start_dir;
    var dir_delta = DIR[@intFromEnum(start_dir)];

    while (grid.get(pos[0], pos[1])) |_| {
        // already reached this point before, we are in a loop
        if (path.previouslySteppedOn(pos[0], pos[1], dir)) {
            // std.debug.print(">> Yes it will\n", .{});
            return true;
        }

        path.stepOn(pos[0], pos[1], dir);

        const next_pos: [2]i64 = .{ pos[0] + dir_delta[0], pos[1] + dir_delta[1] };

        if (grid.get(next_pos[0], next_pos[1]) == '#' or (new_obstacle[0] == next_pos[0] and new_obstacle[1] == next_pos[1])) {
            dir = dir.rotateClockwise();
            dir_delta = DIR[@intFromEnum(dir)];
        } else {
            pos = next_pos;
        }
    }

    return false;
}

fn debugPrintWithObstacle(grid: *const lib.Grid, pos: [2]i64) void {
    std.debug.print("Obstacle at {}, {}\n", .{ pos[0], pos[1] });
    for (0..grid.rows) |yu| {
        for (0..grid.columns) |xu| {
            const x: i64 = @intCast(xu);
            const y: i64 = @intCast(yu);

            if (x == pos[0] and y == pos[1]) {
                std.debug.print("O", .{});
            } else {
                std.debug.print("{c}", .{grid.get(x, y).?});
            }
        }
        std.debug.print("\n", .{});
    }
    std.debug.print("\n", .{});
}

test "example input" {
    const input =
        \\....#.....
        \\.........#
        \\..........
        \\..#.......
        \\.......#..
        \\..........
        \\.#..^.....
        \\........#.
        \\#.........
        \\......#...
    ;
    const res = try solve(input, "\n", std.testing.allocator);

    try std.testing.expectEqual(41, res.part1);
    try std.testing.expectEqual(6, res.part2);
}
