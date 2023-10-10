const std = @import("std");
const demo_github_app = @import("../demo_github_app.zig");

const Self = @This();

allocator: std.mem.Allocator,
app_id: []const u8,
private_key_path: []const u8,

pub const GitHubAppInstallation = struct {
    id: i64,
};

pub const AccessToken = struct {
    token: []const u8,
};

pub fn init(allocator: std.mem.Allocator, app_id: []const u8, private_key_path: []const u8) Self {
    return .{
        .allocator = allocator,
        .app_id = app_id,
        .private_key_path = private_key_path,
    };
}

pub fn getInstallation(self: *const Self, owner: []const u8, repository: []const u8) !GitHubAppInstallation {
    var client = std.http.Client{ .allocator = self.allocator };
    defer client.deinit();

    var headers = std.http.Headers.init(self.allocator);
    defer headers.deinit();
    try headers.append("Accept", "application/vnd.github+json");
    try self.addAuthorizationBearerJWTHeader(&headers);
    const raw_uri = try std.fmt.allocPrint(self.allocator, "https://api.github.com/repos/{s}/{s}/installation", .{ owner, repository });
    defer self.allocator.free(raw_uri);
    const target = try std.Uri.parse(raw_uri);
    var req = try client.request(.GET, target, headers, .{});
    defer req.deinit();

    std.log.info("> GET {}", .{target});
    try req.start(.{});
    try req.wait();
    const body = try req.reader().readAllAlloc(self.allocator, 1024 * 1024);
    defer self.allocator.free(body);
    switch (req.response.status) {
        .ok => {
            std.log.info("< {d}", .{req.response.status});
            std.log.info("< {s}", .{body});
            const installation = try std.json.parseFromSlice(GitHubAppInstallation, self.allocator, body, .{
                .ignore_unknown_fields = true,
            });
            defer installation.deinit();
            return installation.value;
        },
        else => {
            std.log.err("< {d}", .{req.response.status});
            std.log.err("< {s}", .{body});
            return error.InvalidStatus;
        },
    }
}

pub fn getInstallationAccessToken(self: *const Self, installation_id: i64) ![]const u8 {
    var client = std.http.Client{ .allocator = self.allocator };
    defer client.deinit();
    var headers = std.http.Headers.init(self.allocator);
    defer headers.deinit();
    try headers.append("Accept", "application/vnd.github+json");
    try self.addAuthorizationBearerJWTHeader(&headers);
    const raw_uri = try std.fmt.allocPrint(self.allocator, "https://api.github.com/app/installations/{d}/access_tokens", .{installation_id});
    defer self.allocator.free(raw_uri);
    const target = try std.Uri.parse(raw_uri);
    var req = try client.request(.POST, target, headers, .{});
    defer req.deinit();
    std.log.info("> POST {}", .{target});
    try req.start(.{});
    try req.wait();
    const body = try req.reader().readAllAlloc(self.allocator, 1024 * 1024);
    defer self.allocator.free(body);
    switch (req.response.status) {
        .created => {
            std.log.info("< {d}", .{req.response.status});
            std.log.info("< {s}", .{body});
            const p = try std.json.parseFromSlice(AccessToken, self.allocator, body, .{
                .ignore_unknown_fields = true,
            });
            defer p.deinit();
            const token = try self.allocator.alloc(u8, p.value.token.len);
            errdefer self.allocator.free(token);
            std.mem.copy(u8, token, p.value.token);
            return token;
        },
        else => {
            std.log.err("< {d}", .{req.response.status});
            std.log.err("< {s}", .{body});
            return error.InvalidStatus;
        },
    }
}

fn addAuthorizationBearerJWTHeader(self: *const Self, headers: *std.http.Headers) !void {
    const token = try demo_github_app.jwt.generateJWT(self.allocator, self.app_id, self.private_key_path, std.time.timestamp());
    defer self.allocator.free(token);
    const bearer = try std.fmt.allocPrint(self.allocator, "Bearer {s}", .{token});
    defer self.allocator.free(bearer);
    try headers.append("Authorization", bearer);
}

pub fn getRepositoryContent(self: *const Self, owner: []const u8, repository: []const u8, path: []const u8, access_token: []const u8) ![]const u8 {
    var client = std.http.Client{ .allocator = self.allocator };
    defer client.deinit();

    var headers = std.http.Headers.init(self.allocator);
    defer headers.deinit();
    const bearer = try std.fmt.allocPrint(self.allocator, "Bearer {s}", .{access_token});
    defer self.allocator.free(bearer);
    try headers.append("Accept", "application/vnd.github.raw");
    try headers.append("Authorization", bearer);

    const u8_uri = try std.fmt.allocPrint(self.allocator, "https://api.github.com/repos/{s}/{s}/contents/{s}", .{ owner, repository, path });
    defer self.allocator.free(u8_uri);

    const target = try std.Uri.parse(u8_uri);
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

test "github_client: getInstallation - getAccessToken - getRepositoryContent" {
    var gh_client = Self.init(std.testing.allocator, "404064", "src/demo_github_app/mizuochik-demo-github-app.2023-10-06.private-key.pem");
    const installation = try gh_client.getInstallation("mizuochik", "demo-github-app");
    const access_token = try gh_client.getInstallationAccessToken(installation.id);
    defer std.testing.allocator.free(access_token);

    const readme_content = try gh_client.getRepositoryContent("mizuochik", "demo-github-app", "README.md", access_token);
    defer std.testing.allocator.free(readme_content);

    var it = std.mem.split(u8, readme_content, "\n");
    try std.testing.expectEqualStrings("# demo-github-app", it.first());
}
