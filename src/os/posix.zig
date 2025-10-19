const builtin = @import("builtin");
const std = @import("std");
const c = switch (builtin.os.tag) {
    .linux, .macos => @import("c"),
    else => @compileError("This OS is not supported"),
};

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const log = std.log;
const fs = std.fs;
const log10Int = std.math.log10_int;

allocator: Allocator,
stdout: fs.File,
buf: ArrayList(u8),
length: usize,
print_line: usize = 2,

const Self = @This();

pub fn init(allocator: Allocator) !Self {
    var output: Self = undefined;
    output.allocator = allocator;

    var win_info: c.winsize = undefined;
    if (c.ioctl(std.posix.STDOUT_FILENO, c.TIOCGWINSZ, &win_info) < 0) {
        log.err("Cannot get the terminal size", .{});
        return error.TermSizeNotObtained;
    }

    output.stdout = fs.File.stdout();
    output.length = @as(usize, @intCast(win_info.ws_col));

    output.buf = try ArrayList(u8).initCapacity(allocator, output.length * 2);
    errdefer output.buf.deinit(allocator);

    var buf: [1024]u8 = undefined;
    var writer = output.stdout.writer(&buf);
    try writer.interface.writeAll("\x1b[?25l");
    try writer.interface.flush();

    return output;
}

pub fn deinit(self: *Self) void {
    self.buf.deinit(self.allocator);

    var buf: [1024]u8 = undefined;
    var writer = self.stdout.writer(&buf);
    writer.interface.writeAll("\x1b[?25h") catch @panic("stdout write failed");
    writer.interface.flush() catch @panic("stdout write failed");
}

pub fn print(
    self: *Self,
    current: usize,
    total: usize,
) !void {
    self.buf.clearRetainingCapacity();

    var buf: [4096]u8 = undefined;
    var buf_writer = self.stdout.writer(&buf);
    const writer = &buf_writer.interface;

    const raw_progress_len = blk: {
        const to_discard = 2 * log10Int(total) + 8;
        break :blk self.length -| to_discard;
    };
    const percent = @divTrunc(current * raw_progress_len, total);

    try writer.writeByte('[');
    for (0..raw_progress_len) |j| {
        if (j <= percent) {
            try writer.writeByte('=');
        } else {
            try writer.writeByte(' ');
        }
    }
    try writer.print("] {}/{}\r", .{ current, total });
    try writer.flush();
}

pub fn printExt(
    self: *Self,
    current: usize,
    total: usize,
    comptime format: []const u8,
    args: anytype,
) !void {
    self.buf.clearRetainingCapacity();

    var buf: [4096]u8 = undefined;
    var buf_writer = self.stdout.writer(&buf);
    const writer = &buf_writer.interface;

    const raw_progress_len = blk: {
        const to_discard = 2 * log10Int(total) + 8;
        break :blk self.length -| to_discard;
    };
    const percent = @divTrunc(current * raw_progress_len, total);

    try writer.print(format, args);
    try writer.writeByte('[');
    for (0..raw_progress_len) |j| {
        if (j <= percent) {
            try writer.writeByte('=');
        } else {
            try writer.writeByte(' ');
        }
    }
    try writer.print("] {}/{}\r", .{ current, total });
    try writer.flush();
}

pub fn paddingNewline(self: *Self) !void {
    var buf: [4096]u8 = undefined;
    var writer = self.stdout.writer(&buf);
    for (0..self.print_line + 1) |_| {
        try writer.interface.writeByte('\n');
    }
    try writer.interface.flush();
}
