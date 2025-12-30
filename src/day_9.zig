const std = @import("std");
const lib = @import("aoc_2024");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    const input = try lib.read_input(allocator, 9);
    defer allocator.free(input);

    const result = try solve(input, allocator);

    std.log.info("Part 1: {}", .{result.part1});
    std.log.info("Part 2: {}", .{result.part2});
}

const Section = union(enum) {
    empty: struct { len: u16 },
    occupied: struct { val: usize, len: u16 },
};

fn solve(input: []const u8, allocator: std.mem.Allocator) !lib.Solution {
    var data = try parseData(input, allocator);
    defer data.clearAndFree(allocator);

    var fragmented = try data.clone(allocator);
    defer fragmented.clearAndFree(allocator);

    try fragmentedCompaction(&fragmented, allocator);
    const fragmented_checksum = calculateChecksum(fragmented.items);

    // std.debug.print("Before compaction:\n", .{});
    // debugPrint(data.items);

    try wholeCompaction(&data, allocator);

    // std.debug.print("After compaction:\n", .{});
    // debugPrint(data.items);

    const whole_checksum = calculateChecksum(data.items);

    return .{
        .part1 = fragmented_checksum,
        .part2 = whole_checksum,
    };
}

fn parseData(input: []const u8, allocator: std.mem.Allocator) !std.ArrayList(Section) {
    var data = try std.ArrayList(Section).initCapacity(allocator, input.len);

    for (input, 0..) |c, i| {
        if (i % 2 == 0) {
            data.appendAssumeCapacity(.{ .occupied = .{ .val = i / 2, .len = @intCast(c - '0') } });
        } else {
            data.appendAssumeCapacity(.{ .empty = .{ .len = @intCast(c - '0') } });
        }
    }

    return data;
}

fn debugPrint(d: []Section) void {
    for (d) |s| {
        switch (s) {
            .empty => |e| {
                for (0..e.len) |_| {
                    std.debug.print(".", .{});
                }
            },
            .occupied => |o| {
                for (0..o.len) |_| {
                    std.debug.print("{}", .{o.val});
                }
            },
        }
    }
    std.debug.print("\n", .{});
}

test "parse test" {
    const input = "12345";
    var res = try parseData(input, std.testing.allocator);
    defer res.clearAndFree(std.testing.allocator);

    try std.testing.expectEqual(5, res.items.len);

    try std.testing.expect(res.items[0] == .occupied);
    try std.testing.expectEqual(1, res.items[0].occupied.len);
    try std.testing.expectEqual(0, res.items[0].occupied.val);

    try std.testing.expect(res.items[1] == .empty);
    try std.testing.expectEqual(2, res.items[1].empty.len);

    try std.testing.expect(res.items[2] == .occupied);
    try std.testing.expectEqual(3, res.items[2].occupied.len);
    try std.testing.expectEqual(1, res.items[2].occupied.val);

    try std.testing.expect(res.items[3] == .empty);
    try std.testing.expectEqual(4, res.items[3].empty.len);

    try std.testing.expect(res.items[4] == .occupied);
    try std.testing.expectEqual(5, res.items[4].occupied.len);
    try std.testing.expectEqual(2, res.items[4].occupied.val);
}

fn fragmentedCompaction(data: *std.ArrayList(Section), allocator: std.mem.Allocator) !void {
    var free: usize = 1;
    while (free < data.items.len) {
        // std.debug.print("Iterating:\n", .{});
        // for (data.items, 0..) |s, i| {
        //     if (i == free) std.debug.print("(free) ", .{});
        //     std.debug.print("{any}\n", .{s});
        // }

        switch (data.items[data.items.len - 1]) {
            .empty => |_| {
                _ = data.pop();
            },
            .occupied => |d| {
                const free_section_len = data.items[free].empty.len;
                const curr_section_len = d.len;

                if (free_section_len == curr_section_len) {
                    const to_put = data.pop().?;
                    data.items[free] = to_put;
                } else if (free_section_len > curr_section_len) {
                    data.items[free].empty.len = free_section_len - curr_section_len;

                    const to_put = data.pop().?;
                    try data.insert(allocator, free, to_put);
                } else { // free len < curr len
                    data.items[free] = .{ .occupied = .{ .len = free_section_len, .val = d.val } };
                    data.items[data.items.len - 1].occupied.len -= free_section_len;
                }
            },
        }

        // advance free if needed
        while (free < data.items.len and data.items[free] != .empty) : (free += 1) {}
    }
}

fn wholeCompaction(data: *std.ArrayList(Section), allocator: std.mem.Allocator) !void {
    var i = data.items.len;
    while (i > 0) {
        i -= 1;
        // std.debug.print("Iterating for ({any}): \n", .{data.items[i]});

        if (data.items[i] == .empty) {
            // std.debug.print("=> Skipping because current is empty\n", .{});
            continue;
        }

        var left: usize = 0;
        while (left < i and !(data.items[left] == .empty and data.items[left].empty.len >= data.items[i].occupied.len)) : (left += 1) {}

        // no empty space available
        if (left == i) {
            // std.debug.print("=> Skipping because no space available left\n", .{});
            continue;
        }

        data.items[left].empty.len -= data.items[i].occupied.len;
        const to_put = data.items[i];
        data.items[i] = .{ .empty = .{ .len = to_put.occupied.len } };

        if (data.items[left].empty.len == 0) {
            data.items[left] = to_put;
        } else {
            try data.insert(allocator, left, to_put);
        }

        compactEmptySections(data, left);

        // std.debug.print("=> Compacted! ", .{});
        // debugPrint(data.items);
    }
}

fn compactEmptySections(data: *std.ArrayList(Section), startIdx: usize) void {
    var i: usize = startIdx;
    while (i < data.items.len - 1) {
        if (data.items[i] == .empty and data.items[i + 1] == .empty) {
            // squish
            data.items[i].empty.len += data.items[i + 1].empty.len;
            _ = data.orderedRemove(i + 1);
        } else {
            i += 1;
        }
    }
}

test "simple fragmented compact test" {
    var res = try parseData("12345", std.testing.allocator);
    defer res.clearAndFree(std.testing.allocator);

    // std.debug.print("Before compaction:\n", .{});
    // for (res.items) |s| {
    //     std.debug.print("{any}\n", .{s});
    // }

    try fragmentedCompaction(&res, std.testing.allocator);

    // std.debug.print("After compaction:\n", .{});
    // for (res.items) |s| {
    //     std.debug.print("{any}\n", .{s});
    // }

    //022111222
    try std.testing.expectEqual(4, res.items.len);

    try std.testing.expect(res.items[0] == .occupied);
    try std.testing.expectEqual(1, res.items[0].occupied.len);
    try std.testing.expectEqual(0, res.items[0].occupied.val);

    try std.testing.expect(res.items[1] == .occupied);
    try std.testing.expectEqual(2, res.items[1].occupied.len);
    try std.testing.expectEqual(2, res.items[1].occupied.val);

    try std.testing.expect(res.items[2] == .occupied);
    try std.testing.expectEqual(3, res.items[2].occupied.len);
    try std.testing.expectEqual(1, res.items[2].occupied.val);

    try std.testing.expect(res.items[3] == .occupied);
    try std.testing.expectEqual(3, res.items[3].occupied.len);
    try std.testing.expectEqual(2, res.items[3].occupied.val);
}

fn calculateChecksum(data: []Section) u64 {
    var result: u64 = 0;
    var idx: u64 = 0;
    for (data) |s| {
        if (s == .empty) {
            idx += s.empty.len;
            continue;
        }

        for (idx..idx + s.occupied.len) |i| {
            result += i * @as(u64, @intCast(s.occupied.val));
        }

        idx += s.occupied.len;
    }

    return result;
}

test "example input" {
    const input = "2333133121414131402";
    const res = try solve(input, std.testing.allocator);

    try std.testing.expectEqual(1928, res.part1);
    try std.testing.expectEqual(2858, res.part2);
}
