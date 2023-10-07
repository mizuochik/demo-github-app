const std = @import("std");

pub fn generateJWT(allocator: std.mem.Allocator, key_pem_path: []const u8, current_epoch_seconds: i64) ![]const u8 {
    const iat_key_value = try std.fmt.allocPrint(allocator, "iat={d}", .{current_epoch_seconds - 60});
    defer allocator.free(iat_key_value);
    const exp_arg = try std.fmt.allocPrint(allocator, "--exp={d}", .{current_epoch_seconds + (10 * 60)});
    defer allocator.free(exp_arg);
    const secret_arg = try std.fmt.allocPrint(allocator, "@{s}", .{key_pem_path});
    defer allocator.free(secret_arg);
    const result = try std.ChildProcess.exec(.{
        .allocator = allocator,
        .argv = &[_][]const u8{
            "jwt",
            "encode",
            "--alg",
            "RS256",
            "--iss",
            "404064",
            exp_arg,
            "--payload",
            iat_key_value,
            "--secret",
            secret_arg,
        },
        .max_output_bytes = 1024 * 1024,
    });
    errdefer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    if (result.term.Exited != 0) {
        std.log.err("failed to run jwt: exit code {}", .{result.term.Exited});
        return error.JWTCLIFailed;
    }
    return result.stdout;
}

test "jwt: generateJWT" {
    const epoch_sec_20230101T000000Z = 1672531200;
    const token = try generateJWT(std.testing.allocator, "src/demo_github_app/mizuochik-demo-github-app.2023-10-06.private-key.pem", epoch_sec_20230101T000000Z);
    defer std.testing.allocator.free(token);
    try std.testing.expectEqualStrings(
        "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJleHAiOjE2NzI1MzE4MDAsImlhdCI6MTY3MjUzMTE0MCwiaXNzIjo0MDQwNjR9.PWgxI3ynJUSUXboXYVOPwLf6V23pnxZ2HrUHSxoyElKMBCcMjjCqiS_wFXeuBr2QCFmPeLk_tSHL0umFqn9fd1Cq7nnu4dU9yKvhbCiaD9h76xl1fBYDwgKDIl4QAHnp1ILyjiYxxtgKKxYz2Ez8ZuIk_Fjui2Y0zgDKeaBI7YekpeHoKpizzcaKqYyRq8OV5373VBtjCneco_AT5csB-GS4j_CVzoljKGoYEMHdlWgEwS7jUCheV1cO2yEUVQE9ZQjc7du5kTD_xlRizUuuWVNMhevwYZlE-6tKYEPFKKI59Q34BHfx3ieUuplDnRJL7xgfudNnLkvGH_VKTf9XOw",
        token,
    );
}
