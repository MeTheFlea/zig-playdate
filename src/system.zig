const playdate = @import("main.zig");
const c = playdate.c;
const std = @import("std");

// Miscellaneous
// https://sdk.play.date/1.12.2/Inside%20Playdate%20with%20C.html#_miscellaneous
pub fn drawFps(x: i32, y: i32) void {
    playdate.api.system.*.drawFPS.?(x, y);
}
pub fn getCurrentTimeMilliseconds() u32 {
    return playdate.api.system.*.getCurrentTimeMilliseconds.?();
}

// Logging
// https://sdk.play.date/1.12.2/Inside%20Playdate%20with%20C.html#_logging
pub fn @"error"(message: []const u8) void {
    const cstr_message = std.cstr.addNullByte(playdate.allocator, message) catch unreachable;
    defer playdate.allocator.free(cstr_message);

    playdate.api.system.*.@"error".?(@ptrCast([*c]const u8, cstr_message));
}
pub fn logToConsole(message: []const u8) void {
    const cstr_message = std.cstr.addNullByte(playdate.allocator, message) catch unreachable;
    defer playdate.allocator.free(cstr_message);

    playdate.api.system.*.logToConsole.?(@ptrCast([*c]const u8, cstr_message));
}

// Buttons
// https://sdk.play.date/1.12.2/Inside%20Playdate%20with%20C.html#_buttons
pub const PDButton = enum(usize) {
    Left = c.kButtonLeft,
    Right = c.kButtonRight,
    Up = c.kButtonUp,
    Down = c.kButtonDown,
    B = c.kButtonB,
    A = c.kButtonA,
};
pub const TotalButtonState = struct {
    current: ButtonState,
    pushed: ButtonState,
    released: ButtonState,
};
pub const ButtonState = packed struct {
    left: bool,
    right: bool,
    up: bool,
    down: bool,
    b: bool,
    a: bool,
};
pub fn getButtonState() TotalButtonState {
    var current: PDButton = undefined;
    var pushed: PDButton = undefined;
    var released: PDButton = undefined;
    playdate.api.system.*.getButtonState.?(@ptrCast([*c]c_uint, &current), @ptrCast([*c]c_uint, &pushed), @ptrCast([*c]c_uint, &released));

    const current_int = @enumToInt(current);
    const pushed_int = @enumToInt(pushed);
    const released_int = @enumToInt(released);
    return .{
        .current = ButtonState{
            .left = (current_int & @enumToInt(PDButton.Left)) == @enumToInt(PDButton.Left),
            .right = (current_int & @enumToInt(PDButton.Right)) == @enumToInt(PDButton.Right),
            .up = (current_int & @enumToInt(PDButton.Up)) == @enumToInt(PDButton.Up),
            .down = (current_int & @enumToInt(PDButton.Down)) == @enumToInt(PDButton.Down),
            .b = (current_int & @enumToInt(PDButton.B)) == @enumToInt(PDButton.B),
            .a = (current_int & @enumToInt(PDButton.A)) == @enumToInt(PDButton.A),
        },
        .pushed = ButtonState{
            .left = (pushed_int & @enumToInt(PDButton.Left)) == @enumToInt(PDButton.Left),
            .right = (pushed_int & @enumToInt(PDButton.Right)) == @enumToInt(PDButton.Right),
            .up = (pushed_int & @enumToInt(PDButton.Up)) == @enumToInt(PDButton.Up),
            .down = (pushed_int & @enumToInt(PDButton.Down)) == @enumToInt(PDButton.Down),
            .b = (pushed_int & @enumToInt(PDButton.B)) == @enumToInt(PDButton.B),
            .a = (pushed_int & @enumToInt(PDButton.A)) == @enumToInt(PDButton.A),
        },
        .released = ButtonState{
            .left = (released_int & @enumToInt(PDButton.Left)) == @enumToInt(PDButton.Left),
            .right = (released_int & @enumToInt(PDButton.Right)) == @enumToInt(PDButton.Right),
            .up = (released_int & @enumToInt(PDButton.Up)) == @enumToInt(PDButton.Up),
            .down = (released_int & @enumToInt(PDButton.Down)) == @enumToInt(PDButton.Down),
            .b = (released_int & @enumToInt(PDButton.B)) == @enumToInt(PDButton.B),
            .a = (released_int & @enumToInt(PDButton.A)) == @enumToInt(PDButton.A),
        },
    };
}

// Crank
// https://sdk.play.date/1.12.2/Inside%20Playdate%20with%20C.html#_crank
pub fn getCrankAngle() f32 {
    return playdate.api.system.*.getCrankAngle.?();
}
pub fn getCrankChange() f32 {
    return playdate.api.system.*.getCrankChange.?();
}
pub fn isCrankDocked() bool {
    return playdate.api.system.*.isCrankDocked.?() == 1;
}

// Interacting with the System Menu
// https://sdk.play.date/1.12.2/Inside%20Playdate%20with%20C.html#_interacting_with_the_system_menu
pub const MenuItem = anyopaque;

const CallbackWrapper = struct {
    var callback: fn () void = undefined;

    fn call() callconv(.C) void {
        callback();
    }
};

pub fn addMenuItem(title: []const u8, callback: fn (userdata: ?*anyopaque) void, userdata: ?*anyopaque) !*MenuItem {
    const cstr_title = try std.cstr.addNullByte(playdate.allocator, title);
    defer playdate.allocator.free(cstr_title);

    var userdata_wrapper = UserdataWrapper{
        .callback = callback,
        .userdata = userdata,
    };
    const ptr = @ptrCast(*MenuItem, playdate.api.system.*.addMenuItem.?(@ptrCast([*c]const u8, cstr_title), callbackWrapper, @intToPtr(?*anyopaque, UserdataTracker.counter)));

    try UserdataTracker.counter_to_userdata.put(UserdataTracker.counter, userdata_wrapper);
    try UserdataTracker.menu_item_to_counter.put(ptr, UserdataTracker.counter);
    UserdataTracker.counter += 1;

    return ptr;
}
pub fn addCheckmarkMenuItem(title: []const u8, value: bool, callback: fn (userdata: ?*anyopaque) void, userdata: ?*anyopaque) !*MenuItem {
    const cstr_title = try std.cstr.addNullByte(playdate.allocator, title);
    defer playdate.allocator.free(cstr_title);

    var userdata_wrapper = UserdataWrapper{
        .callback = callback,
        .userdata = userdata,
    };
    const ptr = @ptrCast(*anyopaque, playdate.api.system.*.addCheckmarkMenuItem.?(@ptrCast([*c]const u8, title), if (value) 1 else 0, callbackWrapper, @intToPtr(?*anyopaque, UserdataTracker.counter)));

    try UserdataTracker.counter_to_userdata.put(UserdataTracker.counter, userdata_wrapper);
    try UserdataTracker.menu_item_to_counter.put(ptr, UserdataTracker.counter);
    UserdataTracker.counter += 1;

    return ptr;
}

pub fn addOptionsMenuItem(title: []const u8, options: []const [*:0]const u8, callback: fn (userdata: ?*anyopaque) void, userdata: ?*anyopaque) !*MenuItem {
    const cstr_title = try std.cstr.addNullByte(playdate.allocator, title);
    defer playdate.allocator.free(cstr_title);

    var userdata_wrapper = UserdataWrapper{
        .callback = callback,
        .userdata = userdata,
    };

    const ptr = @ptrCast(*anyopaque, playdate.api.system.*.addOptionsMenuItem.?(@ptrCast([*c]const u8, cstr_title), @intToPtr([*c][*c]u8, @ptrToInt(options.ptr)), @intCast(c_int, options.len), callbackWrapper, @intToPtr(?*anyopaque, UserdataTracker.counter)));

    try UserdataTracker.counter_to_userdata.put(UserdataTracker.counter, userdata_wrapper);
    try UserdataTracker.menu_item_to_counter.put(ptr, UserdataTracker.counter);
    UserdataTracker.counter += 1;

    return ptr;
}
pub fn setMenuItemValue(menu_item: *MenuItem, value: i32) void {
    playdate.api.system.*.setMenuItemValue.?(@ptrCast(*c.PDMenuItem, menu_item), value);
}
pub fn getMenuItemValue(menu_item: *MenuItem) i32 {
    return playdate.api.system.*.getMenuItemValue.?(@ptrCast(*c.PDMenuItem, menu_item));
}
pub fn removeMenuItem(menu_item: *MenuItem) void {
    const counter = UserdataTracker.menu_item_to_counter.get(menu_item);
    UserdataTracker.menu_item_to_counter.swapRemove(menu_item);
    UserdataTracker.counter_to_userdata.swapRemove(counter);

    playdate.api.system.*.removeMenuItem.?(@ptrCast(*c.PDMenuItem, menu_item));
}
pub fn removeAllMenuItems() void {
    UserdataTracker.menu_item_to_counter.clearAndFree();
    UserdataTracker.counter_to_userdata.clearAndFree();

    playdate.api.system.*.removeAllMenuItems.?();
}

const UserdataTracker = struct {
    var counter_to_userdata = std.AutoArrayHashMap(usize, UserdataWrapper).init(playdate.allocator);
    var menu_item_to_counter = std.AutoArrayHashMap(*MenuItem, usize).init(playdate.allocator);
    var counter: usize = 0;
};
const UserdataWrapper = struct { callback: fn (userdata: ?*anyopaque) void, userdata: ?*anyopaque };
fn callbackWrapper(userdata: ?*anyopaque) callconv(.C) void {
    const counter = @ptrToInt(userdata);
    const wrapper = UserdataTracker.counter_to_userdata.get(counter).?;
    wrapper.callback(wrapper.userdata);
}
