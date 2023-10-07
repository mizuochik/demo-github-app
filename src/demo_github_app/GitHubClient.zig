const std = @import("std");
const demo_github_app = @import("../demo_github_app.zig");

const Self = @This();

allocator: std.mem.Allocator,
private_key_path: []const u8,

pub fn init(allocator: std.mem.Allocator, private_key_path: []const u8) Self {
    return .{
        .allocator = allocator,
        .private_key_path = private_key_path,
    };
}

pub fn getInstallations(self: *Self) ![]u8 {
    var client = std.http.Client{ .allocator = self.allocator };
    defer client.deinit();

    const jwt = try demo_github_app.jwt.generateJWT(self.allocator, self.private_key_path, std.time.timestamp());
    defer self.allocator.free(jwt);

    var headers = std.http.Headers.init(self.allocator);
    defer headers.deinit();
    const bearer = try std.fmt.allocPrint(self.allocator, "Bearer {s}", .{jwt});
    defer self.allocator.free(bearer);
    try headers.append("Accept", "application/vnd.github+json");
    try headers.append("Authorization", bearer);

    const target = try std.Uri.parse("https://api.github.com/app/installations");
    var req = try client.request(.GET, target, headers, .{});
    defer req.deinit();

    std.log.info("> GET {}", .{target});
    try req.start(.{});
    try req.wait();
    const body = try req.reader().readAllAlloc(self.allocator, 4096);
    errdefer self.allocator.free(body);
    switch (req.response.status) {
        .ok => {
            std.log.info("< {}", .{req.response.status});
            std.log.info("< {s}", .{body});
            return body;
        },
        else => {
            std.log.err("< {}", .{req.response.status});
            std.log.err("< {s}", .{body});
            return error.InvalidStatus;
        },
    }
}

test "github_client: getInstallations" {
    var gh_client = Self.init(std.testing.allocator, "src/demo_github_app/mizuochik-demo-github-app.2023-10-06.private-key.pem");
    const installations = try gh_client.getInstallations();
    defer std.testing.allocator.free(installations);
}
