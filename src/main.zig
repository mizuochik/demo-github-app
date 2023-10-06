const std = @import("std");
const testing = std.testing;
const log = std.log;

pub fn main() !void {
    log.info("Hello demo-github-app", .{});
}

test {
    testing.refAllDecls(@This());
}
