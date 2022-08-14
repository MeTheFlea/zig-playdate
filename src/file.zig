const playdate = @import("main.zig");
const c = playdate.c;
const std = @import("std");

// Filesystem
// https://sdk.play.date/1.12.2/Inside%20Playdate%20with%20C.html#_filesystem
const FileStat = struct {
    is_dir: bool,
    size: u32,
    m_year: i32,
    m_month: i32,
    m_day: i32,
    m_hour: i32,
    m_minute: i32,
    m_second: i32,
};
pub const FileOptions = enum(c_uint) {
    Read = c.kFileRead, //
    ReadData = c.kFileReadData,
    Write = c.kFileWrite,
    Append = c.kFileAppend,
};
pub const SDFile = anyopaque;

pub fn geterr() []const u8 {
    const err = playdate.api.file.*.geterr.?();
    return std.mem.sliceTo(err, 0);
}
pub fn listfiles(path: []const u8, callback: fn (filename: []const u8, userdata: ?*anyopaque) void, userdata: ?*anyopaque, show_hidden: bool) !void {
    const c_str = try std.cstr.addNullByte(playdate.allocator, path);
    defer playdate.allocator.free(c_str);

    var userdata_wrapper = UserdataWrapper{
        .callback = callback,
        .userdata = userdata,
    };

    if (playdate.api.file.*.listfiles.?(c_str, callbackWrapper, @ptrCast(*anyopaque, &userdata_wrapper), if (show_hidden) 1 else 0) != 0) {
        return error.FilesystemError;
    }
}
pub fn unlink(path: []const u8, recursive: bool) !void {
    const c_str = try std.cstr.addNullByte(playdate.allocator, path);
    defer playdate.allocator.free(c_str);

    if (playdate.api.file.*.unlink.?(c_str, if (recursive) 1 else 0) != 0) {
        return error.FilesystemError;
    }
}
pub fn mkdir(path: []const u8) !void {
    const c_str = try std.cstr.addNullByte(playdate.allocator, path);
    defer playdate.allocator.free(c_str);

    if (playdate.api.file.*.mkdir.?(c_str) != 0) {
        return error.FilesystemError;
    }
}
pub fn rename(from: []const u8, to: []const u8) !void {
    const c_from = try std.cstr.addNullByte(playdate.allocator, from);
    defer playdate.allocator.free(c_from);
    const c_to = try std.cstr.addNullByte(playdate.allocator, to);
    defer playdate.allocator.free(c_to);

    if (playdate.api.file.*.rename.?(c_from, c_to) != 0) {
        return error.FilesystemError;
    }
}
pub fn stat(path: []const u8) !FileStat {
    const c_path = try std.cstr.addNullByte(playdate.allocator, path);
    defer playdate.allocator.free(c_path);

    var c_filestat = c.FileStat{
        .isdir = undefined,
        .size = undefined,
        .m_year = undefined,
        .m_month = undefined,
        .m_day = undefined,
        .m_hour = undefined,
        .m_minute = undefined,
        .m_second = undefined,
    };

    if (playdate.api.file.*.stat.?(c_path, &c_filestat) != 0) {
        return error.FilesystemError;
    }

    return FileStat{
        .is_dir = c_filestat.isdir == 1,
        .size = c_filestat.size,
        .m_year = c_filestat.m_year,
        .m_month = c_filestat.m_month,
        .m_day = c_filestat.m_day,
        .m_hour = c_filestat.m_hour,
        .m_minute = c_filestat.m_minute,
        .m_second = c_filestat.m_second,
    };
}

const UserdataWrapper = struct { callback: fn (filename: []const u8, userdata: ?*anyopaque) void, userdata: ?*anyopaque };
fn callbackWrapper(filename: [*c]const u8, userdata: ?*anyopaque) callconv(.C) void {
    const wrapper = @ptrCast(*UserdataWrapper, @alignCast(@alignOf(*UserdataWrapper), userdata));
    wrapper.callback(std.mem.sliceTo(filename, 0), wrapper.userdata);
}

// Files
// https://sdk.play.date/1.12.2/Inside%20Playdate%20with%20C.html#_files
pub fn open(path: []const u8, mode: FileOptions) !*SDFile {
    const c_path = try std.cstr.addNullByte(playdate.allocator, path);
    defer playdate.allocator.free(c_path);

    const ptr = playdate.api.file.*.open.?(c_path, @enumToInt(mode));
    if (ptr == null) {
        return error.FilesystemError;
    }
    return @ptrCast(*SDFile, ptr);
}
pub fn close(file: *SDFile) !void {
    const val = playdate.api.file.*.close.?(file);
    if (val != 0) {
        return error.FilesystemError;
    }
}
pub fn flush(file: *SDFile) !i32 {
    const val = playdate.api.file.*.flush.?(file);
    if (val == -1) {
        return error.FilesystemError;
    }
    return val;
}
pub fn read(file: *SDFile, buf: []u8, len: usize) !usize {
    if (len > buf.len) {
        return error.BufferTooSmall;
    }
    const val = playdate.api.file.*.read.?(file, @ptrCast(*anyopaque, buf.ptr), @intCast(c_uint, len));
    if (val == -1) {
        return error.FilesystemError;
    }
    return val;
}
pub fn write(file: *SDFile, buf: []const u8) !usize {
    // int playdate->file->write(SDFile* file, const void* buf, unsigned int len);

    const val = playdate.api.file.*.write.?(file, @ptrCast(*const anyopaque, buf.ptr), @intCast(c_uint, buf.len));
    if (val == -1) {
        return error.FilesystemError;
    }
    return @intCast(usize, val);
}
