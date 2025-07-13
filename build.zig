const std = @import("std");
const builtin = @import("builtin");

const MIN_ZIG = std.SemanticVersion.parse("0.14.0-dev.2837+f38d7a92c") catch unreachable;
//
// NOTE: This code came from
// https://github.com/zigtools/zls/blob/master/build.zig.
const Build = blk: {
    const current_zig = builtin.zig_version;
    if (current_zig.order(MIN_ZIG) == .lt) {
        @compileError(std.fmt.comptimePrint(
            "Your Zig version v{} does not meet the minimum build requirement of v{}",
            .{ current_zig, MIN_ZIG },
        ));
    }
    break :blk std.Build;
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zg = b.dependency("zg", .{
        .target = target,
        .optimize = optimize,
    });
    const c_header = b.addTranslateC(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .root_source_file = b.path("./src/os/czig.h"),
    });
    const c_header_mod = b.addModule("badepo_c", .{
        .root_source_file = c_header.getOutput(),
        .target = target,
        .optimize = optimize,
    });

    _ = b.addModule("badepo", .{
        .root_source_file = b.path("src/Badepo.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "c", .module = c_header_mod },
            .{ .name = "zg_DisplayWidth", .module = zg.module("DisplayWidth") },
        },
    });
}
