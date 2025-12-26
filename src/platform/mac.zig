const std = @import("std");

const wgpu = @import("wgpu");
const objc = @import("mach-objc");

const input = @import("input.zig");
const window_types = @import("types.zig");
const debug_trace = @import("debug_trace.zig");

const Size = window_types.Size;
const MouseState = window_types.MouseState;
const KeyboardState = window_types.KeyboardState;
const KeyState = window_types.KeyState;
const PlatformKeyAction = window_types.PlatformKeyAction;
const PlatformKeyEvent = window_types.PlatformKeyEvent;
const PlatformTextEvent = window_types.PlatformTextEvent;
const UIEventSink = window_types.UIEventSink;

const log = std.log.scoped(.mac);

var active_platform: ?*MacPlatform = null;

extern const NSPasteboardTypeString: objc.app_kit.PasteboardType;

pub fn setAppIcon(path: [:0]const u8) void {
    const ns_path = objc.foundation.String.stringWithUTF8String(path);
    const image = objc.app_kit.Image.alloc().initWithContentsOfFile(ns_path) orelse return;
    defer image.release();

    const ns_app = objc.app_kit.Application.sharedApplication();
    objc.objc.msgSend(ns_app, "setApplicationIconImage:", void, .{image});
}

const Pasteboard = opaque {
    pub const InternalInfo = objc.objc.ExternClass("NSPasteboard", Pasteboard, objc.foundation.ObjectInterface, &.{});
    pub const as = InternalInfo.as;
    pub const retain = InternalInfo.retain;
    pub const release = InternalInfo.release;
    pub const autorelease = InternalInfo.autorelease;
    pub const new = InternalInfo.new;
    pub const alloc = InternalInfo.alloc;
    pub const allocInit = InternalInfo.allocInit;

    pub fn generalPasteboard() *Pasteboard {
        return objc.objc.msgSend(InternalInfo.class(), "generalPasteboard", *Pasteboard, .{});
    }

    pub fn clearContents(self: *Pasteboard) objc.app_kit.Integer {
        return objc.objc.msgSend(self, "clearContents", objc.app_kit.Integer, .{});
    }

    pub fn setString_forType(self: *Pasteboard, string: *objc.foundation.String, pasteboard_type: objc.app_kit.PasteboardType) bool {
        return objc.objc.msgSend(self, "setString:forType:", bool, .{ string, pasteboard_type });
    }

    pub fn stringForType(self: *Pasteboard, pasteboard_type: objc.app_kit.PasteboardType) ?*objc.foundation.String {
        return objc.objc.msgSend(self, "stringForType:", ?*objc.foundation.String, .{pasteboard_type});
    }
};

pub const WindowCommand = enum {
    minimize,
    maximize,
    restore,
    close,
};

pub const MacPlatform = struct {
    pub const ResizeHook = struct {
        context: *anyopaque,
        callback: *const fn (*anyopaque, u32, u32) void,
    };

    allocator: std.mem.Allocator,
    window: ?*objc.app_kit.Window = null,
    view: ?*objc.mach.View = null,
    layer: ?*objc.quartz_core.MetalLayer = null,
    window_delegate: ?*objc.mach.WindowDelegate = null,
    should_close: bool = false,
    window_size: Size = .{ .width = 1920, .height = 1080 },
    size_changed: bool = false,
    is_minimized: bool = false,
    mouse_state: MouseState = .{},
    cursor_last: input.CursorType = .default,
    webview_cursor_hint: input.CursorType = .default,
    authoritative_cursor: input.CursorType = .default,
    draggable_rect: ?objc.core_graphics.Rect = null,
    tray_icon_added: bool = false,
    dev_mode: bool = false,
    dvui_text_input_active: bool = false,
    resize_hook: ?ResizeHook = null,
    keyboard_state: KeyboardState = .{},
    ui_event_sink: ?UIEventSink = null,
    key_events: std.ArrayListUnmanaged(PlatformKeyEvent) = .{},
    text_events: std.ArrayListUnmanaged(PlatformTextEvent) = .{},
    cursor_hidden: bool = false,
    mod_shift_down: bool = false,
    mod_control_down: bool = false,
    mod_alt_down: bool = false,
    mod_command_down: bool = false,

    pub fn create() !*MacPlatform {
        const allocator = std.heap.page_allocator;
        const self = try allocator.create(MacPlatform);
        self.* = .{
            .allocator = allocator,
        };
        return self;
    }

    pub fn destroy(self: *MacPlatform) void {
        self.deinit();
        self.allocator.destroy(self);
    }

    pub fn init(self: *MacPlatform) !void {
        active_platform = self;
        const ns_app = objc.app_kit.Application.sharedApplication();
        _ = ns_app.setActivationPolicy(objc.app_kit.ApplicationActivationPolicyRegular);

        const width: objc.core_graphics.Float = @floatFromInt(self.window_size.width);
        const height: objc.core_graphics.Float = @floatFromInt(self.window_size.height);
        const rect = objc.core_graphics.Rect{
            .origin = .{ .x = 0, .y = 0 },
            .size = .{ .width = width, .height = height },
        };

        const style = objc.app_kit.WindowStyleMaskTitled |
            objc.app_kit.WindowStyleMaskClosable |
            objc.app_kit.WindowStyleMaskMiniaturizable |
            objc.app_kit.WindowStyleMaskResizable |
            objc.app_kit.WindowStyleMaskFullSizeContentView;

        const screen = objc.app_kit.Screen.mainScreen();
        const native_window = objc.app_kit.Window.alloc().initWithContentRect_styleMask_backing_defer_screen(
            rect,
            style,
            objc.app_kit.BackingStoreBuffered,
            false,
            screen,
        );
        native_window.setReleasedWhenClosed(false);
        self.window = native_window;

        const title = objc.foundation.String.allocInit();
        defer title.release();
        const title_c: [:0]const u8 = "Clay Engine";
        native_window.setTitle(title.initWithUTF8String(title_c));

        const layer = objc.quartz_core.MetalLayer.new();
        self.layer = layer;

        var view = objc.mach.View.allocInit();
        view = view.initWithFrame(rect);
        view.setLayer(layer);
        self.view = view;

        native_window.setContentView(@ptrCast(view));
        native_window.center();
        native_window.makeKeyAndOrderFront(null);

        const delegate = objc.mach.WindowDelegate.allocInit();
        self.window_delegate = delegate;
        native_window.setDelegate(@ptrCast(delegate));

        const resize_block = objc.foundation.stackBlockLiteral(WindowDelegateCallbacks.windowDidResize, @as(u8, 0), null, null);
        delegate.setBlock_windowDidResize(resize_block.asBlock().copy());
        const close_block = objc.foundation.stackBlockLiteral(WindowDelegateCallbacks.windowShouldClose, @as(u8, 0), null, null);
        delegate.setBlock_windowShouldClose(close_block.asBlock().copy());

        const key_down_block = objc.foundation.stackBlockLiteral(ViewCallbacks.keyDown, @as(u8, 0), null, null);
        view.setBlock_keyDown(key_down_block.asBlock().copy());
        const insert_text_block = objc.foundation.stackBlockLiteral(ViewCallbacks.insertText, @as(u8, 0), null, null);
        view.setBlock_insertText(insert_text_block.asBlock().copy());
        const key_up_block = objc.foundation.stackBlockLiteral(ViewCallbacks.keyUp, @as(u8, 0), null, null);
        view.setBlock_keyUp(key_up_block.asBlock().copy());
        const flags_block = objc.foundation.stackBlockLiteral(ViewCallbacks.flagsChanged, @as(u8, 0), null, null);
        view.setBlock_flagsChanged(flags_block.asBlock().copy());
        const mouse_moved_block = objc.foundation.stackBlockLiteral(ViewCallbacks.mouseMoved, @as(u8, 0), null, null);
        view.setBlock_mouseMoved(mouse_moved_block.asBlock().copy());
        const mouse_down_block = objc.foundation.stackBlockLiteral(ViewCallbacks.mouseDown, @as(u8, 0), null, null);
        view.setBlock_mouseDown(mouse_down_block.asBlock().copy());
        const mouse_up_block = objc.foundation.stackBlockLiteral(ViewCallbacks.mouseUp, @as(u8, 0), null, null);
        view.setBlock_mouseUp(mouse_up_block.asBlock().copy());
        const scroll_block = objc.foundation.stackBlockLiteral(ViewCallbacks.scrollWheel, @as(u8, 0), null, null);
        view.setBlock_scrollWheel(scroll_block.asBlock().copy());

        const command_block = objc.foundation.stackBlockLiteral(CommandCallbacks.commandKeyUp, @as(u8, 0), null, null);
        _ = objc.app_kit.Event.addLocalMonitorForEventsMatchingMask_handler(
            objc.app_kit.EventMaskKeyUp,
            command_block.asBlock().copy(),
        );

        _ = self.updateWindowSize();
    }

    /// Surface descriptor source for Metal layer (kept at module level to ensure lifetime)
    var surface_source_metal_layer: wgpu.SurfaceSourceMetalLayer = undefined;

    pub fn getWgpuSurfaceDescriptor(self: *MacPlatform) !wgpu.SurfaceDescriptor {
        const layer = self.layer orelse return error.MissingMetalLayer;
        surface_source_metal_layer = .{
            .layer = @ptrCast(layer),
        };
        return wgpu.SurfaceDescriptor{
            .next_in_chain = @ptrCast(&surface_source_metal_layer),
            .label = wgpu.StringView.fromSlice("Mac Surface"),
        };
    }

    pub fn deinit(self: *MacPlatform) void {
        if (active_platform == self) {
            active_platform = null;
        }
        self.key_events.deinit(self.allocator);
        self.text_events.deinit(self.allocator);
        if (self.window) |native_window| {
            native_window.setDelegate(null);
            native_window.setContentView(null);
            _ = objc.objc.msgSend(native_window, "close", void, .{});
            native_window.release();
            self.window = null;
        }
        if (self.view) |native_view| {
            native_view.release();
            self.view = null;
        }
        if (self.layer) |native_layer| {
            native_layer.release();
            self.layer = null;
        }
        if (self.window_delegate) |delegate| {
            delegate.release();
            self.window_delegate = null;
        }
    }

    pub fn consumeSizeChanged(self: *MacPlatform) bool {
        const changed = self.size_changed;
        self.size_changed = false;
        return changed;
    }

    pub fn isWindowActive(self: *const MacPlatform) bool {
        const native_window = self.window orelse return false;
        return objc.objc.msgSend(native_window, "isKeyWindow", bool, .{});
    }

    pub fn isMinimized(self: *const MacPlatform) bool {
        const native_window = self.window orelse return false;
        return objc.objc.msgSend(native_window, "isMiniaturized", bool, .{});
    }

    pub fn updateWindowSize(self: *MacPlatform) bool {
        const native_window = self.window orelse return false;
        const frame = native_window.frame();
        const content_rect = native_window.contentRectForFrameRect(frame);
        const new_width: u32 = @intFromFloat(content_rect.size.width);
        const new_height: u32 = @intFromFloat(content_rect.size.height);
        if (self.window_size.width == new_width and self.window_size.height == new_height) return false;
        self.window_size.width = new_width;
        self.window_size.height = new_height;
        self.size_changed = true;
        if (self.layer) |layer| {
            const scale: objc.core_graphics.Float = native_window.backingScaleFactor();
            const width: objc.core_graphics.Float = @floatFromInt(new_width);
            const height: objc.core_graphics.Float = @floatFromInt(new_height);
            const drawable_size = objc.core_graphics.Size{
                .width = width * scale,
                .height = height * scale,
            };
            layer.setDrawableSize(drawable_size);
        }
        return true;
    }

    pub fn setResizeHook(self: *MacPlatform, hook: ?ResizeHook) void {
        self.resize_hook = hook;
    }

    pub fn focusWindow(self: *MacPlatform) void {
        const native_window = self.window orelse return;
        const ns_app = objc.app_kit.Application.sharedApplication();
        ns_app.activateIgnoringOtherApps(true);
        native_window.makeKeyAndOrderFront(null);
    }

    pub fn notifyResizeHook(self: *MacPlatform, width: u32, height: u32) void {
        if (self.resize_hook) |hook| {
            hook.callback(hook.context, width, height);
        }
    }

    pub fn pollEvents(self: *MacPlatform) !bool {
        const pool = objc.objc.autoreleasePoolPush();
        defer objc.objc.autoreleasePoolPop(pool);
        const ns_app = objc.app_kit.Application.sharedApplication();
        while (true) {
            const event = ns_app.nextEventMatchingMask(
                objc.app_kit.EventMaskAny,
                objc.app_kit.Date.distantPast(),
                objc.app_kit.NSDefaultRunLoopMode,
                true,
            );
            if (event == null) break;
            ns_app.sendEvent(event.?);
        }
        ns_app.updateWindows();
        return !self.should_close;
    }

    pub fn setUIEventSink(self: *MacPlatform, sink: ?UIEventSink) void {
        self.ui_event_sink = sink;
    }

    pub fn installWebviewSubclass(self: *MacPlatform) void {
        _ = self;
    }

    pub fn installWebviewChildSubclass(self: *MacPlatform) void {
        _ = self;
    }

    pub fn removeWebviewChildSubclass(self: *MacPlatform) void {
        _ = self;
    }

    pub fn refreshMouseState(self: *MacPlatform) void {
        self.mouse_state.delta_x = self.mouse_state.x - self.mouse_state.prev_x;
        self.mouse_state.delta_y = self.mouse_state.y - self.mouse_state.prev_y;
        self.mouse_state.prev_x = self.mouse_state.x;
        self.mouse_state.prev_y = self.mouse_state.y;
        self.mouse_state.prev_left_button_down = self.mouse_state.left_button_down;
        self.mouse_state.prev_right_button_down = self.mouse_state.right_button_down;
        self.mouse_state.alt_key_down = self.mod_alt_down;
    }

    pub fn setDvuiTextInputActive(self: *MacPlatform, active: bool) void {
        if (self.dvui_text_input_active == active) return;
        self.dvui_text_input_active = active;
    }

    pub fn isDvuiTextInputActive(self: *const MacPlatform) bool {
        return self.dvui_text_input_active;
    }

    pub fn keyEvents(self: *const MacPlatform) []const PlatformKeyEvent {
        return self.key_events.items;
    }

    pub fn textEvents(self: *const MacPlatform) []const PlatformTextEvent {
        return self.text_events.items;
    }

    pub fn clearKeyEvents(self: *MacPlatform) void {
        self.key_events.clearRetainingCapacity();
    }

    pub fn clearTextEvents(self: *MacPlatform) void {
        self.text_events.clearRetainingCapacity();
    }

    pub fn modifierState(self: *const MacPlatform) window_types.Mod {
        _ = self;
        const flags = objc.app_kit.Event.T_modifierFlags();
        return modifierStateFromFlags(flags);
    }

    pub fn notifyMouseMove(self: *MacPlatform) void {
        debug_trace.setMousePos(self.mouse_state.x, self.mouse_state.y);
        if (self.ui_event_sink) |sink| {
            debug_trace.setUiSinkState(
                sink.context,
                true,
                sink.mouse_button != null,
                sink.mouse_move != null,
                sink.mouse_wheel != null,
            );
            self.mouse_state.last_ui_event_ns = std.time.nanoTimestamp();
            if (sink.mouse_move) |handler| {
                handler(sink.context, self.mouse_state.x, self.mouse_state.y);
            }
        } else {
            debug_trace.setUiSinkState(null, false, false, false, false);
        }
    }

    pub fn notifyMouseButton(self: *MacPlatform, button: input.MouseButton, pressed: bool) void {
        debug_trace.setTag("notify_mouse_button");
        debug_trace.setMouse(@intCast(@intFromEnum(button)), pressed, self.mouse_state.x, self.mouse_state.y);
        if (self.ui_event_sink) |sink| {
            debug_trace.setUiSinkState(
                sink.context,
                true,
                sink.mouse_button != null,
                sink.mouse_move != null,
                sink.mouse_wheel != null,
            );
            self.mouse_state.last_ui_event_ns = std.time.nanoTimestamp();
            if (sink.mouse_button) |handler| {
                handler(sink.context, button, pressed, self.mouse_state.x, self.mouse_state.y);
            }
        } else {
            debug_trace.setUiSinkState(null, false, false, false, false);
        }
    }

    pub fn notifyMouseWheel(self: *MacPlatform, delta_x: f32, delta_y: f32) void {
        if (self.ui_event_sink) |sink| {
            debug_trace.setUiSinkState(
                sink.context,
                true,
                sink.mouse_button != null,
                sink.mouse_move != null,
                sink.mouse_wheel != null,
            );
            self.mouse_state.last_ui_event_ns = std.time.nanoTimestamp();
            if (sink.mouse_wheel) |handler| {
                handler(sink.context, delta_x, delta_y, self.mouse_state.x, self.mouse_state.y);
            }
        } else {
            debug_trace.setUiSinkState(null, false, false, false, false);
        }

        if (delta_y > 0) {
            self.mouse_state.wheel_delta_y_pos += delta_y;
        } else if (delta_y < 0) {
            self.mouse_state.wheel_delta_y_neg += delta_y;
        }
    }

    pub fn setCursor(self: *MacPlatform, cursor: input.CursorType) !void {
        self.authoritative_cursor = cursor;
        debug_trace.setCursor(@intCast(@intFromEnum(cursor)));
        if (cursor == self.cursor_last) return;
        defer self.cursor_last = cursor;

        if (cursor == .none) {
            if (!self.cursor_hidden) {
                objc.app_kit.Cursor.hide();
                self.cursor_hidden = true;
            }
            return;
        }

        if (self.cursor_hidden) {
            objc.app_kit.Cursor.unhide();
            self.cursor_hidden = false;
        }

        const ns_cursor = cursorForType(cursor);
        objc.app_kit.Cursor.T_pop();
        ns_cursor.push();
    }

    pub fn isCursorOverWindow(self: *const MacPlatform) bool {
        _ = self;
        return true;
    }

    pub fn computeResizeCursorAtCursor(self: *MacPlatform) ?input.CursorType {
        _ = self;
        return null;
    }

    pub fn setClipboardText(self: *MacPlatform, text: []const u8) !void {
        std.debug.print("[Clipboard] setClipboardText: \"{s}\"\n", .{text});
        const pasteboard = Pasteboard.generalPasteboard();
        _ = pasteboard.clearContents();
        const text_z = try self.allocator.dupeZ(u8, text);
        defer self.allocator.free(text_z);
        const ns_string = objc.foundation.String.allocInit();
        defer ns_string.release();
        _ = ns_string.initWithUTF8String(text_z.ptr);
        if (!pasteboard.setString_forType(ns_string, NSPasteboardTypeString)) {
            return error.ClipboardSetFailed;
        }
        std.debug.print("[Clipboard] setClipboardText: success\n", .{});
    }

    pub fn clipboardText(self: *MacPlatform, allocator: std.mem.Allocator) ![]const u8 {
        _ = self;
        const pasteboard = Pasteboard.generalPasteboard();
        const ns_string = pasteboard.stringForType(NSPasteboardTypeString) orelse {
            std.debug.print("[Clipboard] clipboardText: empty\n", .{});
            return "";
        };
        const c_string = ns_string.UTF8String();
        const slice = std.mem.span(c_string);
        std.debug.print("[Clipboard] clipboardText: \"{s}\"\n", .{slice});
        return allocator.dupe(u8, slice);
    }

    pub fn addTrayIcon(self: *MacPlatform, _: *anyopaque) !void {
        _ = self;
    }

    pub fn removeTrayIcon(self: *MacPlatform) void {
        _ = self;
    }

    pub fn postWindowCommand(self: *MacPlatform, command: WindowCommand) void {
        const native_window = self.window orelse return;
        switch (command) {
            .minimize => {
                _ = objc.objc.msgSend(native_window, "miniaturize:", void, .{null});
            },
            .maximize => {
                _ = objc.objc.msgSend(native_window, "zoom:", void, .{null});
            },
            .restore => {
                _ = objc.objc.msgSend(native_window, "deminiaturize:", void, .{null});
            },
            .close => {
                _ = objc.objc.msgSend(native_window, "performClose:", void, .{null});
            },
        }
    }

    pub fn beginSystemDrag(self: *MacPlatform) void {
        const native_window = self.window orelse return;
        const ns_app = objc.app_kit.Application.sharedApplication();
        const event = objc.objc.msgSend(ns_app, "currentEvent", ?*objc.app_kit.Event, .{}) orelse return;
        _ = objc.objc.msgSend(native_window, "performWindowDragWithEvent:", void, .{event});
    }

    pub fn beginSystemResize(self: *MacPlatform, _: []const u8) void {
        _ = self;
    }

    pub fn setDraggableRect(self: *MacPlatform, rect: ?objc.core_graphics.Rect) void {
        self.draggable_rect = rect;
    }

    pub fn setWebviewCursorHint(self: *MacPlatform, cursor: input.CursorType) void {
        self.webview_cursor_hint = cursor;
    }
};

const CommandCallbacks = struct {
    pub fn commandKeyUp(block: *objc.foundation.BlockLiteral(u8), event: *objc.app_kit.Event) callconv(.c) ?*objc.app_kit.Event {
        _ = block;
        const plat = active_platform orelse return event;
        const native_window = plat.window orelse return event;
        if (event.modifierFlags() & objc.app_kit.EventModifierFlagCommand != 0) {
            native_window.sendEvent(event);
        }
        return event;
    }
};

const WindowDelegateCallbacks = struct {
    pub fn windowDidResize(block: *objc.foundation.BlockLiteral(u8)) callconv(.c) void {
        _ = block;
        const plat = active_platform orelse return;
        if (plat.updateWindowSize()) {
            plat.notifyResizeHook(plat.window_size.width, plat.window_size.height);
        }
    }

    pub fn windowShouldClose(block: *objc.foundation.BlockLiteral(u8)) callconv(.c) bool {
        _ = block;
        const plat = active_platform orelse return true;
        plat.should_close = true;
        return false;
    }
};

const ViewCallbacks = struct {
    pub fn mouseMoved(block: *objc.foundation.BlockLiteral(u8), event: *objc.app_kit.Event) callconv(.c) void {
        _ = block;
        const plat = active_platform orelse return;
        updateMousePosition(plat, event.locationInWindow());
        // std.debug.print("[Input] mouseMoved: ({}, {})\n", .{ plat.mouse_state.x, plat.mouse_state.y });
        plat.notifyMouseMove();
    }

    pub fn mouseDown(block: *objc.foundation.BlockLiteral(u8), event: *objc.app_kit.Event) callconv(.c) void {
        _ = block;
        const plat = active_platform orelse return;
        updateMousePosition(plat, event.locationInWindow());
        const button = mouseButtonFromNumber(@intCast(event.buttonNumber())) orelse return;
        // std.debug.print("[Input] mouseDown: {s} at ({}, {})\n", .{ @tagName(button), plat.mouse_state.x, plat.mouse_state.y });
        if (button == .left) {
            plat.mouse_state.left_button_down = true;
        } else if (button == .right) {
            plat.mouse_state.right_button_down = true;
        }
        plat.notifyMouseButton(button, true);
    }

    pub fn mouseUp(block: *objc.foundation.BlockLiteral(u8), event: *objc.app_kit.Event) callconv(.c) void {
        _ = block;
        const plat = active_platform orelse return;
        updateMousePosition(plat, event.locationInWindow());
        const button = mouseButtonFromNumber(@intCast(event.buttonNumber())) orelse return;
        // std.debug.print("[Input] mouseUp: {s} at ({}, {})\n", .{ @tagName(button), plat.mouse_state.x, plat.mouse_state.y });
        if (button == .left) {
            plat.mouse_state.left_button_down = false;
        } else if (button == .right) {
            plat.mouse_state.right_button_down = false;
        }
        plat.notifyMouseButton(button, false);
    }

    pub fn scrollWheel(block: *objc.foundation.BlockLiteral(u8), event: *objc.app_kit.Event) callconv(.c) void {
        _ = block;
        const plat = active_platform orelse return;
        var delta_x = event.scrollingDeltaX();
        var delta_y = event.scrollingDeltaY();
        if (event.hasPreciseScrollingDeltas()) {
            delta_x *= 0.1;
            delta_y *= 0.1;
        }
        // std.debug.print("[Input] scrollWheel: dx={d:.2}, dy={d:.2}\n", .{ delta_x, delta_y });
        plat.notifyMouseWheel(@floatCast(delta_x), @floatCast(delta_y));
    }

    pub fn keyDown(block: *objc.foundation.BlockLiteral(u8), event: *objc.app_kit.Event) callconv(.c) void {
        _ = block;
        const plat = active_platform orelse return;
        const key = keyFromKeycode(event.keyCode());
        if (key == window_types.Key.unknown) return;
        const mods = modifierStateFromFlags(event.modifierFlags());
        const action: PlatformKeyAction = if (event.isARepeat()) .repeat else .down;
        // std.debug.print("[Input] keyDown: {s} ({s})\n", .{ @tagName(key), @tagName(action) });
        appendKeyEvent(plat, key, action, mods);
    }

    pub fn insertText(block: *objc.foundation.BlockLiteral(u8), event: *objc.app_kit.Event, codepoint: u32) callconv(.c) void {
        _ = block;
        _ = event;
        const plat = active_platform orelse return;
        const cp: u21 = @intCast(codepoint);
        const len = std.unicode.utf8CodepointSequenceLength(cp) catch return;
        var buffer: [4]u8 = undefined;
        const written = std.unicode.utf8Encode(cp, buffer[0..len]) catch return;
        // std.debug.print("[Input] insertText: \"{s}\"\n", .{buffer[0..written]});
        var text_event = PlatformTextEvent{};
        text_event.len = @intCast(written);
        std.mem.copyForwards(u8, text_event.buffer[0..written], buffer[0..written]);
        plat.text_events.append(plat.allocator, text_event) catch |err| {
            log.err("failed to append text event: {s}", .{@errorName(err)});
        };
    }

    pub fn keyUp(block: *objc.foundation.BlockLiteral(u8), event: *objc.app_kit.Event) callconv(.c) void {
        _ = block;
        const plat = active_platform orelse return;
        const key = keyFromKeycode(event.keyCode());
        if (key == window_types.Key.unknown) return;
        const mods = modifierStateFromFlags(event.modifierFlags());
        std.debug.print("[Input] keyUp: {s}\n", .{@tagName(key)});
        appendKeyEvent(plat, key, .up, mods);
    }

    pub fn flagsChanged(block: *objc.foundation.BlockLiteral(u8), event: *objc.app_kit.Event) callconv(.c) void {
        _ = block;
        const plat = active_platform orelse return;
        // std.debug.print("[Input] flagsChanged: 0x{x}\n", .{event.modifierFlags()});
        handleFlagsChanged(plat, event);
    }
};

fn updateMousePosition(plat: *MacPlatform, location: objc.core_graphics.Point) void {
    const height: objc.core_graphics.Float = @floatFromInt(plat.window_size.height);
    plat.mouse_state.x = @intFromFloat(location.x);
    plat.mouse_state.y = @intFromFloat(height - location.y);
}

fn mouseButtonFromNumber(button_number: usize) ?input.MouseButton {
    return switch (button_number) {
        0 => .left,
        1 => .right,
        2 => .middle,
        3 => .back,
        4 => .forward,
        else => null,
    };
}

fn updateKeyState(state: *KeyState, down_now: bool) void {
    const previous = state.down;
    state.down = down_now;
    state.prev_down = previous;
}

fn modifierStateFromFlags(flags: usize) window_types.Mod {
    var mods = window_types.Mod.none;
    if (flags & objc.app_kit.EventModifierFlagShift != 0) mods.combine(.lshift);
    if (flags & objc.app_kit.EventModifierFlagControl != 0) mods.combine(.lcontrol);
    if (flags & objc.app_kit.EventModifierFlagOption != 0) mods.combine(.lalt);
    if (flags & objc.app_kit.EventModifierFlagCommand != 0) mods.combine(.lcommand);
    return mods;
}

fn handleFlagsChanged(plat: *MacPlatform, event: *objc.app_kit.Event) void {
    const flags = event.modifierFlags();
    const mods = modifierStateFromFlags(flags);

    const shift_now = flags & objc.app_kit.EventModifierFlagShift != 0;
    if (shift_now != plat.mod_shift_down) {
        plat.mod_shift_down = shift_now;
        appendKeyEvent(plat, .left_shift, if (shift_now) .down else .up, mods);
    }

    const control_now = flags & objc.app_kit.EventModifierFlagControl != 0;
    if (control_now != plat.mod_control_down) {
        plat.mod_control_down = control_now;
        appendKeyEvent(plat, .left_control, if (control_now) .down else .up, mods);
    }

    const alt_now = flags & objc.app_kit.EventModifierFlagOption != 0;
    if (alt_now != plat.mod_alt_down) {
        plat.mod_alt_down = alt_now;
        appendKeyEvent(plat, .menu, if (alt_now) .down else .up, mods);
    }

    const command_now = flags & objc.app_kit.EventModifierFlagCommand != 0;
    if (command_now != plat.mod_command_down) {
        plat.mod_command_down = command_now;
        appendKeyEvent(plat, .left_command, if (command_now) .down else .up, mods);
    }
}

fn appendKeyEvent(plat: *MacPlatform, key: window_types.Key, action: PlatformKeyAction, mods: window_types.Mod) void {
    const event = PlatformKeyEvent{
        .code = key,
        .action = action,
        .mods = mods,
    };
    plat.key_events.append(plat.allocator, event) catch |err| {
        log.err("failed to append key event: {s}", .{@errorName(err)});
    };
}

fn cursorForType(cursor: input.CursorType) *objc.app_kit.Cursor {
    return switch (cursor) {
        .pointer => objc.app_kit.Cursor.pointingHandCursor(),
        .text, .vertical_text => objc.app_kit.Cursor.IBeamCursor(),
        .crosshair => objc.app_kit.Cursor.crosshairCursor(),
        .grab => objc.app_kit.Cursor.openHandCursor(),
        .grabbing => objc.app_kit.Cursor.closedHandCursor(),
        .not_allowed => objc.app_kit.Cursor.operationNotAllowedCursor(),
        .resize_col, .resize_e, .resize_w => objc.app_kit.Cursor.resizeLeftRightCursor(),
        .resize_row, .resize_n, .resize_s => objc.app_kit.Cursor.resizeUpDownCursor(),
        .resize_ne, .resize_sw => objc.app_kit.Cursor.resizeLeftRightCursor(),
        .resize_nw, .resize_se => objc.app_kit.Cursor.resizeUpDownCursor(),
        .resize_all => objc.app_kit.Cursor.resizeLeftRightCursor(),
        else => objc.app_kit.Cursor.arrowCursor(),
    };
}

fn keyFromKeycode(keycode: u16) window_types.Key {
    const K = window_types.Key;
    comptime var table: [256]K = undefined;
    comptime for (&table, 1..) |*ptr, idx| {
        ptr.* = switch (idx) {
            0x35 => K.escape,
            0x12 => K.one,
            0x13 => K.two,
            0x14 => K.three,
            0x15 => K.four,
            0x17 => K.five,
            0x16 => K.six,
            0x1A => K.seven,
            0x1C => K.eight,
            0x19 => K.nine,
            0x1D => K.zero,
            0x1B => K.minus,
            0x33 => K.backspace,
            0x30 => K.tab,
            0x0C => K.q,
            0x0D => K.w,
            0x0E => K.e,
            0x0F => K.r,
            0x11 => K.t,
            0x10 => K.y,
            0x20 => K.u,
            0x22 => K.i,
            0x1F => K.o,
            0x23 => K.p,
            0x21 => K.left_bracket,
            0x1E => K.right_bracket,
            0x24 => K.enter,
            0x3B => K.left_control,
            0x01 => K.s,
            0x02 => K.d,
            0x03 => K.f,
            0x05 => K.g,
            0x04 => K.h,
            0x26 => K.j,
            0x28 => K.k,
            0x25 => K.l,
            0x29 => K.semicolon,
            0x27 => K.apostrophe,
            0x32 => K.grave,
            0x38 => K.left_shift,
            0x06 => K.z,
            0x07 => K.x,
            0x08 => K.c,
            0x09 => K.v,
            0x0B => K.b,
            0x2D => K.n,
            0x2E => K.m,
            0x2C => K.slash,
            0x3C => K.right_shift,
            0x43 => K.kp_multiply,
            0x3A => K.menu,
            0x31 => K.space,
            0x39 => K.caps_lock,
            0x7A => K.f1,
            0x78 => K.f2,
            0x63 => K.f3,
            0x76 => K.f4,
            0x60 => K.f5,
            0x61 => K.f6,
            0x62 => K.f7,
            0x64 => K.f8,
            0x65 => K.f9,
            0x6D => K.f10,
            0x59 => K.kp_7,
            0x5B => K.kp_8,
            0x5C => K.kp_9,
            0x4E => K.kp_subtract,
            0x56 => K.kp_4,
            0x57 => K.kp_5,
            0x58 => K.kp_6,
            0x45 => K.kp_add,
            0x53 => K.kp_1,
            0x54 => K.kp_2,
            0x55 => K.kp_3,
            0x52 => K.kp_0,
            0x41 => K.kp_decimal,
            0x69 => K.print,
            0x2A => K.backslash,
            0x67 => K.f11,
            0x6F => K.f12,
            0x51 => K.kp_equal,
            0x6B => K.f14,
            0x71 => K.f15,
            0x6A => K.f16,
            0x40 => K.f17,
            0x4F => K.f18,
            0x50 => K.f19,
            0x5A => K.f20,
            0x4C => K.kp_enter,
            0x3E => K.right_control,
            0x4B => K.kp_divide,
            0x3D => K.menu,
            0x47 => K.num_lock,
            0x73 => K.home,
            0x7E => K.up,
            0x74 => K.page_up,
            0x7B => K.left,
            0x7C => K.right,
            0x77 => K.end,
            0x7D => K.down,
            0x79 => K.page_down,
            0x72 => K.insert,
            0x75 => K.delete,
            0x37 => K.left_command,
            0x36 => K.right_command,
            0x6E => K.menu,
            else => K.unknown,
        };
    };
    return if (keycode > 0 and keycode <= table.len) table[keycode - 1] else if (keycode == 0) K.a else K.unknown;
}
