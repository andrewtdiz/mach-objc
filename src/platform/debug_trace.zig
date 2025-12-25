const std = @import("std");

pub var last_tag: []const u8 = "start";
pub var last_mouse_x: i32 = 0;
pub var last_mouse_y: i32 = 0;
pub var last_button: i32 = -1;
pub var last_pressed: bool = false;
pub var last_cursor: u32 = 0;
pub var last_ui_sink_present: bool = false;
pub var last_ui_button_present: bool = false;
pub var last_ui_move_present: bool = false;
pub var last_ui_wheel_present: bool = false;
pub var last_ui_context: usize = 0;
pub var last_ui_tag: []const u8 = "";

pub fn setTag(tag: []const u8) void {
    last_tag = tag;
}

pub fn setMouse(button: i32, pressed: bool, x: i32, y: i32) void {
    last_button = button;
    last_pressed = pressed;
    last_mouse_x = x;
    last_mouse_y = y;
}

pub fn setMousePos(x: i32, y: i32) void {
    last_mouse_x = x;
    last_mouse_y = y;
}

pub fn setCursor(cursor: u32) void {
    last_cursor = cursor;
}

pub fn setUiTag(tag: []const u8) void {
    last_ui_tag = tag;
}

pub fn setUiSinkState(
    context: ?*anyopaque,
    sink_present: bool,
    button_present: bool,
    move_present: bool,
    wheel_present: bool,
) void {
    last_ui_sink_present = sink_present;
    last_ui_button_present = button_present;
    last_ui_move_present = move_present;
    last_ui_wheel_present = wheel_present;
    if (context) |ctx| {
        last_ui_context = @intFromPtr(ctx);
    } else {
        last_ui_context = 0;
    }
}

pub fn dump() void {
    std.debug.print(
        "panic breadcrumb={s} mouse=({d},{d}) button={d} pressed={} cursor={d} ui_sink={} ui_button={} ui_move={} ui_wheel={} ui_ctx=0x{x} ui_tag={s}\n",
        .{
            last_tag,
            last_mouse_x,
            last_mouse_y,
            last_button,
            last_pressed,
            last_cursor,
            last_ui_sink_present,
            last_ui_button_present,
            last_ui_move_present,
            last_ui_wheel_present,
            last_ui_context,
            last_ui_tag,
        },
    );
}
