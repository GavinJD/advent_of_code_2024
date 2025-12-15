const std = @import("std");
const lib = @import("aoc_2024");

pub fn main() void {
    std.debug.print("Day {}!", .{lib.add(0, 1)});
}
