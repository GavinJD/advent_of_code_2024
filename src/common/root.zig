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

// test "basic add functionality" {
//     try std.testing.expect(add(3, 7) == 10);
// }
