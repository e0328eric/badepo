const std = @import("std");
const builtin = @import("builtin");

const BADEPO_VERSION_STR = @import("build.zig.zon").version;
const BADEPO_VERSION = std.SemanticVersion.parse(BADEPO_VERSION_STR) catch unreachable;
const MIN_ZIG_STRING = @import("build.zig.zon").minimum_zig_version;
const MIN_ZIG = std.SemanticVersion.parse(MIN_ZIG_STRING) catch unreachable;
const PROGRAM_NAME = @tagName(@import("build.zig.zon").name);
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

    _ = b.addModule(PROGRAM_NAME, .{
        .root_source_file = b.path("src/Badepo.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "c", .module = c_header_mod },
        },
    });
}
