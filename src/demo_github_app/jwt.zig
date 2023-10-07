const std = @import("std");
const zig_jwt = @import("../zig-jwt/jwt.zig");

fn parsePEMFile(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    var f = try std.fs.cwd().openFile(path, .{});
    defer f.close();
    var pem = std.ArrayList(u8).init(std.testing.allocator);
    defer pem.deinit();
    var s = std.io.bufferedReader(f.reader());
    var buf: [1024]u8 = undefined;
    while (s.reader().readUntilDelimiter(&buf, '\n')) |line| {
        if (std.mem.eql(u8, line[0..2], "--")) {
            continue;
        }
        try pem.appendSlice(line);
    } else |err| {
        switch (err) {
            error.EndOfStream => {},
            else => return err,
        }
    }
    const dec = std.base64.Base64Decoder.init(std.base64.standard_alphabet_chars, '=');
    const size = try dec.calcSizeForSlice(pem.items);
    var b = try allocator.alloc(u8, size);
    errdefer allocator.free(b);
    try dec.decode(b, pem.items);
    return b;
}

pub fn generateJWTFromPEMKey(allocator: std.mem.Allocator, file_path: []const u8, current_epoch_seconds: i64) ![]const u8 {
    const key = try parsePEMFile(allocator, file_path);
    defer allocator.free(key);
    const token = try zig_jwt.encode(std.testing.allocator, .HS256, .{
        .iat = current_epoch_seconds - 60,
        .exp = current_epoch_seconds + (10 * 60),
        .iss = "404064",
    }, .{ .key = key });
    errdefer allocator.free(token);
    return token;
}

test "jwt: generateJWTFromPEMKey" {
    const epoch_sec_20230101T000000Z = 1672531200;
    const token = try generateJWTFromPEMKey(std.testing.allocator, "src/demo_github_app/mizuochik-demo-github-app.2023-10-06.private-key.pem", epoch_sec_20230101T000000Z);
    defer std.testing.allocator.free(token);
    try std.testing.expectEqualStrings("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpYXQiOjE2NzI1MzExNDAsImV4cCI6MTY3MjUzMTgwMCwiaXNzIjoiNDA0MDY0In0._3-D3mkSjgLGRh220PQPzzKgkl5vhJwUsNyGp65_8xg", token);
}
