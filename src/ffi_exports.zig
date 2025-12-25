const std = @import("std");
const mach = @import("mach-objc");
const objc = mach.objc;

const mac_platform = @import("platform/mac.zig");
const SimpleSwapChain = @import("platform/simple_swap_chain.zig").SimpleSwapChain;
const titlebar = @import("platform/titlebar.zig");
const app_icon = @import("platform/app_icon.zig");
const webview = @import("platform/webview.zig");
const drag_overlay = @import("platform/drag_overlay.zig");
const window_types = @import("platform/types.zig");
const input = @import("platform/input.zig");

var g_platform: ?*mac_platform.MacPlatform = null;
var g_renderer: ?SimpleSwapChain = null;
var g_pool: ?*objc.AutoreleasePool = null;

// ============================================================================
// Lifecycle Functions
// ============================================================================

export fn mach_init(width: u32, height: u32) callconv(.c) i32 {
    g_pool = objc.autoreleasePoolPush();

    g_platform = mac_platform.MacPlatform.create() catch return -1;
    const platform = g_platform.?;

    platform.window_size = .{ .width = width, .height = height };
    platform.init() catch return -2;
    platform.focusWindow();

    const metal_layer = platform.layer orelse return -3;
    g_renderer = SimpleSwapChain.init(
        @ptrCast(metal_layer),
        width,
        height,
    ) catch return -4;

    if (platform.window) |window| {
        titlebar.customize(window);
        _ = webview.WebViewOverlay.init(window);
        drag_overlay.init(window);
    }

    return 0;
}

export fn mach_destroy() callconv(.c) void {
    if (g_renderer) |*renderer| {
        renderer.deinit();
        g_renderer = null;
    }
    if (g_platform) |platform| {
        platform.destroy();
        g_platform = null;
    }
    if (g_pool) |pool| {
        objc.autoreleasePoolPop(pool);
        g_pool = null;
    }
}

// ============================================================================
// Event Loop
// ============================================================================

export fn mach_poll_events() callconv(.c) i32 {
    const platform = g_platform orelse return 0;
    const should_continue = platform.pollEvents() catch return 0;
    return if (should_continue) 1 else 0;
}

export fn mach_render() callconv(.c) i32 {
    const platform = g_platform orelse return 0;
    var renderer = g_renderer orelse return 0;

    if (platform.consumeSizeChanged()) {
        renderer.resize(platform.window_size.width, platform.window_size.height);
        g_renderer = renderer;
    }

    return if (renderer.render()) 1 else 0;
}

export fn mach_tick() callconv(.c) i32 {
    if (mach_poll_events() == 0) return 0;
    return mach_render();
}

// ============================================================================
// Window Control
// ============================================================================

export fn mach_focus_window() callconv(.c) void {
    if (g_platform) |platform| {
        platform.focusWindow();
    }
}

export fn mach_minimize() callconv(.c) void {
    if (g_platform) |platform| {
        platform.postWindowCommand(.minimize);
    }
}

export fn mach_maximize() callconv(.c) void {
    if (g_platform) |platform| {
        platform.postWindowCommand(.maximize);
    }
}

export fn mach_restore() callconv(.c) void {
    if (g_platform) |platform| {
        platform.postWindowCommand(.restore);
    }
}

export fn mach_close() callconv(.c) void {
    if (g_platform) |platform| {
        platform.postWindowCommand(.close);
    }
}

export fn mach_is_window_active() callconv(.c) i32 {
    if (g_platform) |platform| {
        return if (platform.isWindowActive()) 1 else 0;
    }
    return 0;
}

export fn mach_is_minimized() callconv(.c) i32 {
    if (g_platform) |platform| {
        return if (platform.isMinimized()) 1 else 0;
    }
    return 0;
}

// ============================================================================
// Window Size
// ============================================================================

export fn mach_get_width() callconv(.c) u32 {
    if (g_platform) |platform| {
        return platform.window_size.width;
    }
    return 0;
}

export fn mach_get_height() callconv(.c) u32 {
    if (g_platform) |platform| {
        return platform.window_size.height;
    }
    return 0;
}

export fn mach_set_size(width: u32, height: u32) callconv(.c) void {
    if (g_platform) |platform| {
        platform.window_size = .{ .width = width, .height = height };
        if (g_renderer) |*renderer| {
            renderer.resize(width, height);
            g_renderer = renderer.*;
        }
    }
}

// ============================================================================
// Mouse State
// ============================================================================

export fn mach_get_mouse_x() callconv(.c) i32 {
    if (g_platform) |platform| {
        return platform.mouse_state.x;
    }
    return 0;
}

export fn mach_get_mouse_y() callconv(.c) i32 {
    if (g_platform) |platform| {
        return platform.mouse_state.y;
    }
    return 0;
}

export fn mach_is_left_button_down() callconv(.c) i32 {
    if (g_platform) |platform| {
        return if (platform.mouse_state.left_button_down) 1 else 0;
    }
    return 0;
}

export fn mach_is_right_button_down() callconv(.c) i32 {
    if (g_platform) |platform| {
        return if (platform.mouse_state.right_button_down) 1 else 0;
    }
    return 0;
}

export fn mach_get_mouse_delta_x() callconv(.c) i32 {
    if (g_platform) |platform| {
        return platform.mouse_state.delta_x;
    }
    return 0;
}

export fn mach_get_mouse_delta_y() callconv(.c) i32 {
    if (g_platform) |platform| {
        return platform.mouse_state.delta_y;
    }
    return 0;
}

// ============================================================================
// Cursor
// ============================================================================

export fn mach_set_cursor(cursor_type: u32) callconv(.c) void {
    if (g_platform) |platform| {
        const cursor: input.CursorType = @enumFromInt(cursor_type);
        platform.setCursor(cursor) catch {};
    }
}

// ============================================================================
// Clipboard
// ============================================================================

export fn mach_set_clipboard(text: [*:0]const u8) callconv(.c) i32 {
    if (g_platform) |platform| {
        const slice = std.mem.sliceTo(text, 0);
        platform.setClipboardText(slice) catch return -1;
        return 0;
    }
    return -1;
}

export fn mach_get_clipboard(buffer: [*]u8, buffer_len: u32) callconv(.c) i32 {
    if (g_platform) |platform| {
        const text = platform.clipboardText(std.heap.c_allocator) catch return -1;
        defer if (text.len > 0) std.heap.c_allocator.free(text);

        if (text.len > buffer_len) return -2;
        @memcpy(buffer[0..text.len], text);
        return @intCast(text.len);
    }
    return -1;
}

// ============================================================================
// Keyboard State
// ============================================================================

export fn mach_get_modifiers() callconv(.c) u32 {
    if (g_platform) |platform| {
        const mods = platform.modifierState();
        var result: u32 = 0;
        if (mods.shift()) result |= 1;
        if (mods.control()) result |= 2;
        if (mods.alt()) result |= 4;
        if (mods.command()) result |= 8;
        return result;
    }
    return 0;
}

export fn mach_key_event_count() callconv(.c) u32 {
    if (g_platform) |platform| {
        return @intCast(platform.keyEvents().len);
    }
    return 0;
}

export fn mach_get_key_event(index: u32, action_out: *u32, mods_out: *u32) callconv(.c) i32 {
    if (g_platform) |platform| {
        const events = platform.keyEvents();
        if (index >= events.len) return -1;

        const event = events[index];
        action_out.* = @intFromEnum(event.action);
        mods_out.* = @intFromBool(event.mods.shift()) |
            (@as(u32, @intFromBool(event.mods.control())) << 1) |
            (@as(u32, @intFromBool(event.mods.alt())) << 2) |
            (@as(u32, @intFromBool(event.mods.command())) << 3);
        return @intFromEnum(event.code);
    }
    return -1;
}

export fn mach_clear_key_events() callconv(.c) void {
    if (g_platform) |platform| {
        platform.clearKeyEvents();
    }
}

export fn mach_text_event_count() callconv(.c) u32 {
    if (g_platform) |platform| {
        return @intCast(platform.textEvents().len);
    }
    return 0;
}

export fn mach_get_text_event(index: u32, buffer: [*]u8, buffer_len: u32) callconv(.c) i32 {
    if (g_platform) |platform| {
        const events = platform.textEvents();
        if (index >= events.len) return -1;

        const text = events[index].slice();
        if (text.len > buffer_len) return -2;
        @memcpy(buffer[0..text.len], text);
        return @intCast(text.len);
    }
    return -1;
}

export fn mach_clear_text_events() callconv(.c) void {
    if (g_platform) |platform| {
        platform.clearTextEvents();
    }
}

// ============================================================================
// App Icon
// ============================================================================

export fn mach_set_app_icon(path: [*:0]const u8) callconv(.c) void {
    app_icon.set(std.mem.span(path));
}

// ============================================================================
// Text Input Mode
// ============================================================================

export fn mach_enable_text_input() callconv(.c) void {
    if (g_platform) |platform| {
        platform.setDvuiTextInputActive(true);
    }
}

export fn mach_disable_text_input() callconv(.c) void {
    if (g_platform) |platform| {
        platform.setDvuiTextInputActive(false);
    }
}

export fn mach_is_text_input_active() callconv(.c) i32 {
    if (g_platform) |platform| {
        return if (platform.isDvuiTextInputActive()) 1 else 0;
    }
    return 0;
}
