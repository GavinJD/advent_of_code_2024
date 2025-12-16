const std = @import("std");
const lib = @import("aoc_2024");

pub fn main() !void {
    var alloc = std.heap.DebugAllocator(.{}){};
    // defer _ = alloc.detectLeaks();
    const allocator = alloc.allocator();

    const input = try lib.read_input(allocator, 1);
    defer allocator.free(input);

    var left = try std.ArrayList(u32).initCapacity(allocator, 100);
    defer left.clearAndFree(allocator);
    var right = try std.ArrayList(u32).initCapacity(allocator, 100);
    defer right.clearAndFree(allocator);

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        var nums = std.mem.tokenizeAny(u8, line, " \t\r\n");
        const left_num = nums.next().?;
        const right_num = nums.next().?;

        try left.append(allocator, try std.fmt.parseInt(u32, left_num, 10));
        try right.append(allocator, try std.fmt.parseInt(u32, right_num, 10));
    }

    std.mem.sort(u32, left.items, {}, std.sort.asc(u32));
    std.mem.sort(u32, right.items, {}, std.sort.asc(u32));

    var distance: u32 = 0;
    for (0..left.items.len) |i| {
        distance += @max(left.items[i], right.items[i]) - @min(left.items[i], right.items[i]);
    }

    std.debug.print("Part 1: Total distance - {}\n", .{distance});

    var right_counts = std.AutoHashMap(u32, u32).init(allocator);
    for (right.items) |rn| {
        if (right_counts.getEntry(rn)) |e| {
            e.value_ptr.* += 1;
        } else {
            try right_counts.put(rn, 1);
        }
    }

    var similarity: u32 = 0;
    for (left.items) |ln| {
        similarity += ln * (right_counts.get(ln) orelse 0);
    }

    std.debug.print("Part 2: Similarity score - {}", .{similarity});
}
