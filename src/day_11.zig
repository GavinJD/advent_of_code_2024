const std = @import("std");
const lib = @import("aoc_2024");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    const input = try lib.read_input(allocator, 11);
    defer allocator.free(input);

    const result = try solve(input, allocator);

    std.log.info("Part 1: {}", .{result.part1});
    std.log.info("Part 2: {}", .{result.part2});
}

// Slow solving
// fn solve(input: []const u8, allocator: std.mem.Allocator) !lib.Solution {
//     var stones = std.ArrayList(u64).empty;
//     defer stones.deinit(allocator);

//     var nums = std.mem.tokenizeScalar(u8, input, ' ');
//     while (nums.next()) |num| {
//         try stones.append(allocator, try std.fmt.parseInt(u64, num, 10));
//     }

//     var buffer = std.ArrayList(u64).empty;
//     defer buffer.deinit(allocator);

//     var memory = lib.HashSet(u64).init(allocator);
//     defer memory.deinit();

//     var part1: u64 = undefined;
//     for (0..75) |i| {
//         defer buffer.clearRetainingCapacity();
//         std.log.info("{}/75, memory={}, stones={}", .{ i + 1, memory.count(), stones.items.len });

//         if (i == 25) part1 = stones.items.len;

//         for (stones.items) |stone| {
//             if (stone == 0) {
//                 try memory.put(1, {});
//                 try buffer.append(allocator, 1);
//             } else if (digits(stone) % 2 == 0) {
//                 const parts = splitStone(stone);
//                 try memory.put(parts.left, {});
//                 try buffer.append(allocator, parts.left);
//                 try memory.put(parts.right, {});
//                 try buffer.append(allocator, parts.right);
//             } else {
//                 try memory.put(stone * 2024, {});
//                 try buffer.append(allocator, stone * 2024);
//             }
//         }

//         const tmp = stones;
//         stones = buffer;
//         buffer = tmp;
//     }

//     return .{ .part1 = part1, .part2 = stones.items.len };
// }

// Fast solve: Keep track of count of stones and use that instead, since distinct stones increase very slowly
// thank you reddit
fn solve(input: []const u8, allocator: std.mem.Allocator) !lib.Solution {
    var stoneCount = std.AutoHashMap(u64, u64).init(allocator);
    defer stoneCount.deinit();

    var nums = std.mem.tokenizeScalar(u8, input, ' ');
    while (nums.next()) |num| {
        const parsed = try std.fmt.parseInt(u64, num, 10);
        const entry = try stoneCount.getOrPutValue(parsed, 0);
        entry.value_ptr.* += 1;
    }

    var part1: u64 = undefined;
    var buffer = std.AutoHashMap(u64, u64).init(allocator);
    defer buffer.deinit();
    for (0..75) |i| {
        // clear buffer at end
        defer {
            var it = buffer.iterator();
            while (it.next()) |entry| {
                entry.value_ptr.* = 0;
            }
        }

        if (i == 25) part1 = sumValues(&stoneCount);

        var it = stoneCount.iterator();
        while (it.next()) |entry| {
            const stone = entry.key_ptr.*;
            const count = entry.value_ptr.*;

            const next = blink(stone);
            switch (next) {
                .one => |o| {
                    const e = try buffer.getOrPutValue(o.val, 0);
                    e.value_ptr.* += count;    
                },
                .two => |t| {
                    const l = try buffer.getOrPutValue(t.left, 0);
                    l.value_ptr.* += count;    

                    const r = try buffer.getOrPutValue(t.right, 0);
                    r.value_ptr.* += count;    
                }
            }
        }

        const tmp = stoneCount;
        stoneCount = buffer;
        buffer = tmp;
    }

    const part2 = sumValues(&stoneCount);

    return .{ .part1 = part1, .part2 = part2 };
}

fn sumValues(map: *const std.AutoHashMap(u64, u64)) u64 {
    var res: u64 = 0;
    var values = map.valueIterator();
    while (values.next()) |v| {
        res += v.*;
    }
    return res;
}

const BlinkedRes = union(enum) {
    one: struct { val: u64 },
    two: struct { left: u64, right: u64 },
};

fn blink(stone: u64) BlinkedRes {
    if (stone == 0) {
        return .{ .one = .{ .val = 1 }};
    } else if (digits(stone) % 2 == 0) {
        const split = splitStone(stone);
        return .{ .two = .{ .left = split.left, .right = split.right }};
    } else {
        return .{ .one = .{ .val = stone * 2024 }};
    }
}

fn digits(n: u64) usize {
    return @intFromFloat(@trunc(@log10(@as(f64, @floatFromInt(n)))) + 1);
}

fn splitStone(stone: u64) struct { left: u64, right: u64 } {
    const stone_digits = digits(stone);

    var tmp = stone;

    // 12345
    var right: u64 = 0;
    for (0..stone_digits / 2) |i| {
        right += std.math.pow(u64, 10, i) * (tmp % 10);
        tmp /= 10;
    }

    var left: u64 = 0;
    for (0..stone_digits / 2) |i| {
        left += std.math.pow(u64, 10, i) * (tmp % 10);
        tmp /= 10;
    }

    return .{ .left = left, .right = right };
}

test "stone split" {
    const res = splitStone(123456);
    try std.testing.expectEqual(res.left, 123);
    try std.testing.expectEqual(res.right, 456);
}

test "stone split 2" {
    const res = splitStone(123006);
    try std.testing.expectEqual(res.left, 123);
    try std.testing.expectEqual(res.right, 6);
}

test "example input" {
    const input = "125 17";
    const res = try solve(input, std.testing.allocator);

    try std.testing.expectEqual(55312, res.part1);
}
