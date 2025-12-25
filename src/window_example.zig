const std = @import("std");
const mach = @import("mach-objc");
const objc = mach.objc;
const app_kit = mach.app_kit;
const foundation = mach.foundation;

const mac_platform = @import("platform/mac.zig");
const SimpleSwapChain = @import("platform/simple_swap_chain.zig").SimpleSwapChain;

var drag_window: ?*app_kit.Window = null;

const Image = opaque {
    pub const InternalInfo = objc.ExternClass("NSImage", @This(), foundation.ObjectInterface, &.{});
    pub const alloc = InternalInfo.alloc;
    pub const release = InternalInfo.release;

    pub fn initWithContentsOfFile(self: *@This(), path: *foundation.String) ?*Image {
        return objc.msgSend(self, "initWithContentsOfFile:", ?*Image, .{path});
    }
};

const DragCallbacks = struct {
    pub fn mouseDown(block: *foundation.BlockLiteral(u8), event: *app_kit.Event) callconv(.c) void {
        _ = block;
        const window = drag_window orelse return;
        window.performWindowDragWithEvent(event);
    }
};

pub fn main() !void {
    const pool = objc.autoreleasePoolPush();
    defer objc.autoreleasePoolPop(pool);

    const platform = try mac_platform.MacPlatform.create();
    defer platform.destroy();

    platform.window_size = .{ .width = 800, .height = 600 };
    try platform.init();
    platform.focusWindow();
    setAppIcon();

    if (platform.window) |window| {
        customizeTitleBar(window);
        initWebViewOverlay(window);
        initDragOverlay(window);
    }

    const metal_layer = platform.layer orelse return error.MissingMetalLayer;
    var renderer = try SimpleSwapChain.init(
        @ptrCast(metal_layer),
        platform.window_size.width,
        platform.window_size.height,
    );
    defer renderer.deinit();

    while (try platform.pollEvents()) {
        if (platform.consumeSizeChanged()) {
            renderer.resize(platform.window_size.width, platform.window_size.height);
        }

        if (!renderer.render()) break;
    }
}

fn setAppIcon() void {
    const icon_path: [:0]const u8 = "src/assets/appicon.png";
    const ns_path = foundation.String.stringWithUTF8String(icon_path);
    const image = Image.alloc().initWithContentsOfFile(ns_path) orelse return;
    const ns_app = app_kit.Application.sharedApplication();
    objc.msgSend(ns_app, "setApplicationIconImage:", void, .{image});
    image.release();
}

fn initWebViewOverlay(window: *app_kit.Window) void {
    const content_view = window.contentView() orelse return;
    const bounds = objc.msgSend(content_view, "bounds", app_kit.Rect, .{});
    const configuration = app_kit.WebViewConfiguration.allocInit();
    const web_view = app_kit.WebView.alloc().initWithFrame_configuration(bounds, configuration);
    configuration.release();

    const web_view_view = web_view.as(app_kit.View);
    web_view_view.setAutoresizingMask(app_kit.ViewWidthSizable | app_kit.ViewHeightSizable);

    const html: [:0]const u8 =
        \\<html>
        \\<head>
        \\<style>
        \\* { margin: 0; padding: 0; box-sizing: border-box; }
        \\body { 
        \\  width: 100vw; 
        \\  height: 100vh; 
        \\  overflow: hidden;
        \\  font: 16px sans-serif;
        \\  color: white;
        \\  display: grid;
        \\  grid-template-rows: 60px 1fr 200px;
        \\  grid-template-columns: 200px 1fr 200px;
        \\  grid-template-areas:
        \\    "header header header"
        \\    "left center right"
        \\    "bottom bottom bottom";
        \\}
        \\#header { 
        \\  grid-area: header; 
        \\  background: rgba(40, 40, 50, 0.9); 
        \\  padding: 20px;
        \\  border-bottom: 1px solid rgba(255,255,255,0.1);
        \\}
        \\#left { 
        \\  grid-area: left; 
        \\  background: rgba(30, 30, 40, 0.8); 
        \\  padding: 20px;
        \\  border-right: 1px solid rgba(255,255,255,0.1);
        \\}
        \\#right { 
        \\  grid-area: right; 
        \\  background: rgba(30, 30, 40, 0.8); 
        \\  padding: 20px;
        \\  border-left: 1px solid rgba(255,255,255,0.1);
        \\}
        \\#bottom { 
        \\  grid-area: bottom; 
        \\  background: rgba(30, 30, 40, 0.8); 
        \\  padding: 20px;
        \\  border-top: 1px solid rgba(255,255,255,0.1);
        \\}
        \\#center { 
        \\  grid-area: center; 
        \\  background: transparent;
        \\}
        \\</style>
        \\</head>
        \\<body>
        \\<div id="header">Window Header</div>
        \\<div id="left">Left Panel</div>
        \\<div id="center"></div>
        \\<div id="right">Right Panel</div>
        \\<div id="bottom">Bottom Panel</div>
        \\</body>
        \\</html>
    ;
    const html_string = foundation.String.stringWithUTF8String(html);
    web_view.loadHTMLString_baseURL(html_string, null);

    web_view.setOpaque(false);

    const draws_background_key_c: [:0]const u8 = "drawsBackground";
    const draws_background_key = foundation.String.stringWithUTF8String(draws_background_key_c);
    const draws_background_value = foundation.Number.numberWithBool(false);
    web_view.setValue_forKey(@ptrCast(draws_background_value), draws_background_key);

    content_view.addSubView(@ptrCast(web_view));
    web_view.release();
}

fn initDragOverlay(window: *app_kit.Window) void {
    drag_window = window;
    const content_view = window.contentView() orelse return;
    const bounds = objc.msgSend(content_view, "bounds", app_kit.Rect, .{});
    const drag_height: mach.core_graphics.Float = 28;
    const origin_y: mach.core_graphics.Float = bounds.size.height - drag_height;
    const frame = app_kit.Rect{
        .origin = .{ .x = 0, .y = origin_y },
        .size = .{ .width = bounds.size.width, .height = drag_height },
    };
    var drag_view = mach.mach.View.allocInit();
    drag_view = drag_view.initWithFrame(frame);
    const drag_view_base = drag_view.as(app_kit.View);
    drag_view_base.setAutoresizingMask(app_kit.ViewWidthSizable | app_kit.ViewMinYMargin);
    const drag_block = foundation.stackBlockLiteral(DragCallbacks.mouseDown, @as(u8, 0), null, null);
    drag_view.setBlock_mouseDown(drag_block.asBlock().copy());
    content_view.addSubView(@ptrCast(drag_view));
    drag_view.release();
}

fn customizeTitleBar(window: *app_kit.Window) void {
    window.setTitlebarAppearsTransparent(true);
    window.setTitleVisibility(app_kit.WindowTitleHidden);
    window.setBackgroundColor(app_kit.Color.clearColor());
    window.setMovableByWindowBackground(true);

    const traffic_light_x: mach.core_graphics.Float = 12;
    const button_spacing: mach.core_graphics.Float = 20;

    // Get the close button's superview (the titlebar container) and force its layout
    if (window.standardWindowButton(app_kit.WindowButtonClose)) |close_btn| {
        if (objc.msgSend(close_btn, "superview", ?*app_kit.View, .{})) |container| {
            objc.msgSend(container, "layoutSubtreeIfNeeded", void, .{});
        }
        const frame = close_btn.frame();
        close_btn.setFrameOrigin(.{ .x = traffic_light_x, .y = frame.origin.y });
    }
    if (window.standardWindowButton(app_kit.WindowButtonMiniaturize)) |mini_btn| {
        const frame = mini_btn.frame();
        mini_btn.setFrameOrigin(.{ .x = traffic_light_x + button_spacing, .y = frame.origin.y });
    }
    if (window.standardWindowButton(app_kit.WindowButtonZoom)) |zoom_btn| {
        const frame = zoom_btn.frame();
        zoom_btn.setFrameOrigin(.{ .x = traffic_light_x + button_spacing * 2, .y = frame.origin.y });
    }
}
