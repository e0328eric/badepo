const builtin = @import("builtin");
const std = @import("std");
const c = switch (builtin.os.tag) {
    .linux, .macos => @import("c"),
    else => @compileError("This OS is not supported"),
};

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const DisplayWidth = @import("zg_DisplayWidth");

const log = std.log;
const io = std.io;
const log10Int = std.math.log10_int;

dw: DisplayWidth,
stdout: @TypeOf(io.bufferedWriter(io.getStdOut().writer())),
buf: ArrayList(u8),
length: usize,
print_line: usize = 2,

const Self = @This();

pub fn init(allocator: Allocator) !Self {
    var output: Self = undefined;

    output.dw = try DisplayWidth.init(allocator);
    errdefer output.dw.deinit();

    const stdout = io.getStdOut();

    var win_info: c.winsize = undefined;
    if (c.ioctl(std.posix.STDOUT_FILENO, c.TIOCGWINSZ, &win_info) < 0) {
        log.err("Cannot get the terminal size", .{});
        return error.TermSizeNotObtained;
    }

    output.stdout = io.bufferedWriter(stdout.writer());
    output.length = @as(usize, @intCast(win_info.ws_col));

    output.buf = try ArrayList(u8).initCapacity(allocator, output.length * 2);
    errdefer output.buf.deinit();

    var writer = output.stdout.writer();
    try writer.writeAll("\x1b[?25l");
    try output.stdout.flush();

    return output;
}

pub fn deinit(self: *Self) void {
    self.buf.deinit();
    var writer = self.stdout.writer();
    writer.writeAll("\x1b[?25h") catch @panic("stdout write failed");
    self.stdout.flush() catch @panic("stdout write failed");
    self.dw.deinit();
}

pub fn print(
    self: *Self,
    current: usize,
    total: usize,
    comptime maybe_fmt_str: ?[]const u8,
    args: anytype,
) !void {
    self.buf.clearRetainingCapacity();

    var writer = self.stdout.writer();

    const raw_progress_len = blk: {
        const to_discard = 2 * log10Int(total) + 8;
        break :blk self.length -| to_discard;
    };
    const percent = @divTrunc(current * raw_progress_len, total);

    if (maybe_fmt_str) |fmt_str| {
        try self.buf.writer().print(fmt_str, args);
        self.print_line = @divTrunc(self.dw.strWidth(
            self.buf.items,
            .half,
        ), self.length) +| 1;

        try writer.print(fmt_str, args);
        try writer.writeByte('[');
        for (0..raw_progress_len) |j| {
            if (j <= percent) {
                try writer.writeByte('=');
            } else {
                try writer.writeByte(' ');
            }
        }
        try writer.print("] {}/{}\x1b[{}F", .{ current, total, self.print_line });
    } else {
        try writer.writeByte('[');
        for (0..raw_progress_len) |j| {
            if (j <= percent) {
                try writer.writeByte('=');
            } else {
                try writer.writeByte(' ');
            }
        }
        try writer.print("] {}/{}\r", .{ current, total });
    }
    try self.stdout.flush();
}

pub fn paddingNewline(self: *Self) !void {
    var writer = self.stdout.writer();
    try writer.writeByteNTimes('\n', self.print_line + 1);
    try self.stdout.flush();
}
