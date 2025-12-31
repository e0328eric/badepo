const std = @import("std");
const win = @import("c");
const log = std.log;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Io = std.Io;

const log10Int = std.math.log10_int;

allocator: Allocator,
io: Io,
win_stdout: win.HANDLE,
stdout: Io.File,
buf: ArrayList(u8),
length: usize,
print_line: usize = 2,

const Self = @This();

pub fn init(allocator: Allocator, io: Io) !Self {
    var output: Self = undefined;
    output.allocator = allocator;
    output.io = io;

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

    output.stdout = Io.File.stdout();
    output.length = @as(usize, @intCast(console_info.dwSize.X));

    output.buf = try ArrayList(u8).initCapacity(allocator, output.length * 2);
    errdefer output.buf.deinit(allocator);

    var buf: [1024]u8 = undefined;
    var writer = output.stdout.writer(io, &buf);
    try writer.interface.writeAll("\x1b[?25l");
    try writer.interface.flush();

    return output;
}

pub fn deinit(self: *Self) void {
    self.buf.deinit(self.allocator);

    var buf: [1024]u8 = undefined;
    var writer = self.stdout.writer(self.io, &buf);
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
    var buf_writer = self.stdout.writer(self.io, &buf);
    const writer = &buf_writer.interface;

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

    try writer.writeByte('[');
    for (0..raw_progress_len) |j| {
        if (j <= percent) {
            try writer.writeByte('=');
        } else {
            try writer.writeByte(' ');
        }
    }
    try writer.print("] {}/{}", .{ current, total });
    try writer.flush();
}

pub fn paddingNewline(self: *Self) !void {
    var buf: [4096]u8 = undefined;
    var writer = self.stdout.writer(self.io, &buf);
    for (0..self.print_line + 1) |_| {
        try writer.interface.writeByte('\n');
    }
    try writer.interface.flush();
}
