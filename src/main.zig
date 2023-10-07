const std = @import("std");
const demo_github_app = @import("demo_github_app.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    std.log.info("Hello demo-github-app", .{});
}
