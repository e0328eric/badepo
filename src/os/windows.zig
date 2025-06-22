const std = @import("std");
const win = @cImport({
    @cDefine("WIN32_LEAN_AND_MEAN", {});
    @cInclude("windows.h");
});
const log = std.log;
const io = std.io;
const ziglyph = @import("ziglyph");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const log10Int = std.math.log10_int;

win_stdout: win.HANDLE,
stdout: @TypeOf(io.bufferedWriter(io.getStdOut().writer())),
buf: ArrayList(u8),
length: usize,
print_line: usize = 2,

const Self = @This();

pub fn init(allocator: Allocator) !Self {
    var output: Self = undefined;

    output.win_stdout = win.GetStdHandle(win.STD_OUTPUT_HANDLE);
    if (output.win_stdout == win.INVALID_HANDLE_VALUE) {
        log.err("cannot get the stdout handle", .{});
        return error.CannotGetStdHandle;
    }

    var console_info: win.CONSOLE_SCREEN_BUFFER_INFO = undefined;
    if (win.GetConsoleScreenBufferInfo(output.win_stdout, &console_info) != win.TRUE) {
        log.err("cannot get the console screen buffer info", .{});
        return error.CannotGetConsoleScreenBufInfo;
    }

    const stdout = io.getStdOut();
    output.stdout = io.bufferedWriter(stdout.writer());
    output.length = @as(usize, @intCast(console_info.dwSize.X));

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
}

pub fn print(
    self: *Self,
    current: usize,
    total: usize,
    comptime maybe_fmt_str: ?[]const u8,
    args: anytype,
) !void {
    self.buf.clearRetainingCapacity();

    const writer = self.stdout.writer();

    var console_info: win.CONSOLE_SCREEN_BUFFER_INFO = undefined;
    if (win.GetConsoleScreenBufferInfo(self.win_stdout, &console_info) != win.TRUE) {
        log.err("cannot get the console screen buffer info", .{});
        return error.CannotGetConsoleScreenBufInfo;
    }
    const cursor_pos = console_info.dwCursorPosition;

    _ = win.SetConsoleCursorPosition(self.win_stdout, .{ .X = 0, .Y = cursor_pos.Y });

    const raw_progress_len = blk: {
        const to_discard = 2 * log10Int(total) + 8;
        break :blk self.length -| to_discard;
    };
    const percent = @divTrunc(current * raw_progress_len, total);

    if (maybe_fmt_str) |fmt_str| {
        try self.buf.writer().print(fmt_str, args);
        self.print_line = @divTrunc(ziglyph.display_width.strWidth(
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
        try writer.print("] {}/{}", .{ current, total });
    }
    try self.stdout.flush();
}

pub fn paddingNewline(self: *Self) !void {
    var writer = self.stdout.writer();
    try writer.writeByteNTimes('\n', self.print_line + 1);
    try self.stdout.flush();
}
