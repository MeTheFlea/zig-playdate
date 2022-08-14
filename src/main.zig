const std = @import("std");
pub const c = @cImport({
    @cDefine("TARGET_PLAYDATE", "1");
    @cDefine("TARGET_EXTENSION", "1");
    @cInclude("pd_api.h");
});

pub const graphics = @import("graphics.zig");
pub const system = @import("system.zig");
pub const display = @import("display.zig");
pub const file = @import("file.zig");

pub const allocator = std.mem.Allocator{
    .ptr = undefined,
    .vtable = &@import("allocator.zig").vtable,
};

pub var api: *c.PlaydateAPI = undefined;

pub const SystemEvent = enum(usize) {
    Init = c.kEventInit,
    InitLua = c.kEventInitLua,
    Lock = c.kEventLock,
    Unlock = c.kEventUnlock,
    Pause = c.kEventPause,
    Resume = c.kEventResume,
    Terminate = c.kEventTerminate,
    KeyPressed = c.kEventKeyPressed,
    KeyReleased = c.kEventKeyReleased,
    LowPower = c.kEventLowPower,
};
export fn eventHandler(playdate_api: *c.PlaydateAPI, event: c.PDSystemEvent, arg: u32) callconv(.C) c_int {
    _ = arg;
    if (event == c.kEventInit) {
        api = playdate_api;
        api.system.*.setUpdateCallback.?(updateCallback, null);
    }

    handleEvent(@intToEnum(SystemEvent, event));

    return 0;
}

pub extern fn handleEvent(event: SystemEvent) void;
pub extern fn update() bool;

fn updateCallback(userdata: ?*anyopaque) callconv(.C) c_int {
    _ = userdata;

    return if (update()) 1 else 0;
}

// Define root.log to override the std implementation
pub fn log(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    // Ignore all non-error logging from sources other than
    // .my_project, .nice_library and .default
    const scope_prefix = "(" ++ switch (scope) {
        .my_project, .nice_library, .default => @tagName(scope),
        else => if (@enumToInt(level) <= @enumToInt(std.log.Level.err))
            @tagName(scope)
        else
            return,
    } ++ "): ";

    const prefix = "[" ++ level.asText() ++ "] " ++ scope_prefix;

    const str = nosuspend std.fmt.allocPrint(allocator, prefix ++ format, args) catch return;
    defer allocator.free(str);

    if (level == std.log.Level.err) {
        system.@"error"(str);
    } else {
        system.logToConsole(str);
    }
}
