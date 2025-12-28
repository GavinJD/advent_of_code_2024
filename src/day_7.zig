const std = @import("std");
const lib = @import("aoc_2024");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    const input = try lib.read_input(allocator, 7);
    defer allocator.free(input);

    const result = try solve(input, allocator);

    std.log.info("Part 1: {}", .{result.part1});
    std.log.info("Part 2: {}", .{result.part2});
}

const Operands = enum { multiply, add, concat };

fn solve(input: []const u8, allocator: std.mem.Allocator) !lib.Solution {
    var lines = std.mem.tokenizeAny(u8, input, "\r\n");

    var part1: u64 = 0;
    var part2: u64 = 0;

    var parts = try std.ArrayList(u64).initCapacity(allocator, 20);
    defer parts.clearAndFree(allocator);

    var ops = try std.ArrayList(Operands).initCapacity(allocator, 20);
    defer ops.clearAndFree(allocator);

    while (lines.next()) |line| {
        defer parts.clearRetainingCapacity();
        defer ops.clearRetainingCapacity();

        // std.debug.print("Beginning parse for {s}\n", .{line});

        var nums = std.mem.tokenizeAny(u8, line, " :");
        const total = try std.fmt.parseInt(u64, nums.next().?, 10);

        while (nums.next()) |num| {
            parts.appendAssumeCapacity(try std.fmt.parseInt(u64, num, 10));
        }

        ops.appendNTimesAssumeCapacity(Operands.multiply, parts.items.len - 1);

        // std.debug.print("==> Parsed line 1 ({s}), parts size {}, capacity {}, ops size {}, capacity {}\n", .{ line, parts.items.len, parts.capacity, ops.items.len, ops.capacity });

        if (permutePart1(total, parts.items, ops.items, 0)) {
            part1 += total;
            part2 += total;
        } else if (permutePart2(total, parts.items, ops.items, 0)) {
            part2 += total;
        }
    }

    return .{
        .part1 = part1,
        .part2 = part2,
    };
}

fn permutePart1(total: u64, parts: []u64, ops: []Operands, start: usize) bool {
    if (start >= ops.len) {
        var calculated: u64 = parts[0];
        for (1..parts.len) |i| {
            switch (ops[i - 1]) {
                .multiply => calculated *= parts[i],
                .add => calculated += parts[i],
                else => unreachable,
            }
        }

        return calculated == total;
    }

    inline for (std.meta.fields(Operands)) |field| {
        const op: Operands = @enumFromInt(field.value);
        if (op == Operands.concat) continue;

        ops[start] = op;
        if (permutePart1(total, parts, ops, start + 1)) return true;
    }

    return false;
}

fn permutePart2(total: u64, parts: []u64, ops: []Operands, start: usize) bool {
    if (start >= ops.len) {
        var calculated: u64 = parts[0];
        for (1..parts.len) |i| {
            switch (ops[i - 1]) {
                .multiply => calculated *= parts[i],
                .add => calculated += parts[i],
                .concat => {
                    var digits: u64 = 0;
                    var tmp = parts[i];
                    while (tmp > 0) {
                        tmp /= 10;
                        digits += 1;
                    }

                    calculated *= std.math.pow(u64, 10, digits);
                    calculated += parts[i];
                },
            }
        }

        return calculated == total;
    }

    inline for (std.meta.fields(Operands)) |field| {
        const op: Operands = @enumFromInt(field.value);

        ops[start] = op;
        if (permutePart2(total, parts, ops, start + 1)) return true;
    }

    return false;
}

test "example input" {
    const input =
        \\190: 10 19
        \\3267: 81 40 27
        \\83: 17 5
        \\156: 15 6
        \\7290: 6 8 6 15
        \\161011: 16 10 13
        \\192: 17 8 14
        \\21037: 9 7 18 13
        \\292: 11 6 16 20
    ;
    const res = try solve(input, std.testing.allocator);

    try std.testing.expectEqual(3749, res.part1);
    try std.testing.expectEqual(11387, res.part2);
}
