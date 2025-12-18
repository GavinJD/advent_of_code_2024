const std = @import("std");
const lib = @import("aoc_2024");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    const input = try lib.read_input(allocator, 2);
    defer allocator.free(input);
    var lines = std.mem.splitScalar(u8, input, '\n');

    var safe: i32 = 0;
    var safe_with_dampener: i32 = 0;
    var line_arr = try std.ArrayList(i32).initCapacity(allocator, 10);
    defer line_arr.clearAndFree(allocator);

    while (lines.next()) |line| {
        defer line_arr.clearRetainingCapacity();

        var num_strings = std.mem.tokenizeAny(u8, line, " \r");
        while (num_strings.next()) |num_s| {
            line_arr.appendAssumeCapacity(try std.fmt.parseInt(i32, num_s, 10));
        }

        if (isSafe(line_arr.items)) {
            safe += 1;
            safe_with_dampener += 1;
        } else {
            var temp: []i32 = try allocator.alloc(i32, line_arr.items.len - 1);
            defer allocator.free(temp);

            for (0..line_arr.items.len) |i| {
                std.mem.copyForwards(i32, temp[0..i], line_arr.items[0..i]);
                std.mem.copyForwards(i32, temp[i..], line_arr.items[i + 1 ..]);

                if (isSafe(temp)) {
                    safe_with_dampener += 1;
                    break;
                }
            }
        }
    }

    std.log.info("Part 1: {}", .{safe});
    std.log.info("Part 2: {}", .{safe_with_dampener});
}

fn isSafe(arr: []i32) bool {
    const order_type = std.math.order(arr[0], arr[1]);
    if (order_type == .eq) return false;

    for (0..arr.len - 1) |i| {
        if (@abs(arr[i] - arr[i + 1]) > 3) {
            return false;
        }

        const ord = std.math.order(arr[i], arr[i + 1]);
        if (ord == .eq) {
            return false;
        } else if (ord != order_type) {
            return false;
        }
    }

    return true;
}
