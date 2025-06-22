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

    const ziglyph = b.dependency("ziglyph", .{
        .target = target,
        .optimize = optimize,
    });

    const badepo_mod = b.addModule("badepo", .{
        .root_source_file = b.path("src/Badepo.zig"),
        .target = target,
        .optimize = optimize,
    });
    badepo_mod.addImport("zg_DisplayWidth", ziglyph.module("ziglyph"));
}
