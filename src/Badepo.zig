//! Badepo (barre de progression)
//! This is a simple library for terminal progressbar library written in zig.
const std = @import("std");
const builtin = @import("builtin");

const fmt = std.fmt.comptimePrint;

pub const Badepo = switch (builtin.os.tag) {
    .windows => @import("./os/windows.zig"),
    .linux, .macos => @import("./os/posix.zig"),
    else => @compileError(fmt(
        "Only Linux, Macos, or Windows are supported, but your os is {}.",
        .{builtin.os.tag},
    )),
};
