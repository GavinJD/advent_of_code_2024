const std = @import("std");
const lib = @import("aoc_2024");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    const input = try lib.read_input(allocator, 3);
    defer allocator.free(input);

    const result = solve(input);

    std.log.info("Part 1: {}", .{result.part1});
    std.log.info("Part 2: {}", .{result.part2});
}

fn solve(input: []const u8) struct { part1: u64, part2: u64 } {
    var total_always_enabled: u64 = 0;
    var total_conditional: u64 = 0;
    var enabled = true;
    var idx: usize = 0;

    // stupid solution, search for all 3 strings, pick the closest one
    while (true) {
        const mul_pos = std.mem.indexOfPos(u8, input, idx, "mul(") orelse input.len;
        const do_pos = std.mem.indexOfPos(u8, input, idx, "do()") orelse input.len;
        const dont_pos = std.mem.indexOfPos(u8, input, idx, "don't()") orelse input.len;

        if (mul_pos < do_pos and mul_pos < dont_pos and mul_pos != input.len) {
            idx = mul_pos + 4;
            const n1: u64 = lib.parseNum(input, &idx) catch continue;
            lib.parseExact(input, ",", &idx) catch continue;
            const n2: u64 = lib.parseNum(input, &idx) catch continue;
            lib.parseExact(input, ")", &idx) catch continue;

            total_always_enabled += n1 * n2;
            if (enabled) total_conditional += n1 * n2;
        } else if (do_pos < mul_pos and do_pos < dont_pos and do_pos != input.len) {
            enabled = true;
            idx += 4;
        } else if (dont_pos != input.len) {
            enabled = false;
            idx += 7;
        } else {
            break;
        }
    }

    return .{ .part1 = total_always_enabled, .part2 = total_conditional };
}

test "example input" {
    const test_input = "xmul(2,4)&mul[3,7]!^don't()_mul(5,5)+mul(32,64](mul(11,8)undo()?mul(8,5))";
    const result = solve(test_input);

    try std.testing.expect(result.part1 == 161);
    try std.testing.expect(result.part2 == 48);
}
