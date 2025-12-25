const std = @import("std");
const mach = @import("mach-objc");
const objc = mach.objc;

const mac_platform = @import("platform/mac.zig");
const SimpleSwapChain = @import("platform/simple_swap_chain.zig").SimpleSwapChain;
const titlebar = @import("platform/titlebar.zig");
const app_icon = @import("platform/app_icon.zig");
const webview = @import("platform/webview.zig");
const drag_overlay = @import("platform/drag_overlay.zig");

pub fn main() !void {
    const pool = objc.autoreleasePoolPush();
    defer objc.autoreleasePoolPop(pool);

    const platform = try mac_platform.MacPlatform.create();
    defer platform.destroy();

    platform.window_size = .{ .width = 800, .height = 600 };
    try platform.init();
    platform.focusWindow();

    app_icon.set("src/assets/appicon.png");

    // Test clipboard functionality
    const existing = try platform.clipboardText(std.heap.page_allocator);
    defer if (existing.len > 0) std.heap.page_allocator.free(existing);
    try platform.setClipboardText("Hello from mach-objc!");
    const verify = try platform.clipboardText(std.heap.page_allocator);
    defer if (verify.len > 0) std.heap.page_allocator.free(verify);

    const metal_layer = platform.layer orelse return error.MissingMetalLayer;
    var renderer = try SimpleSwapChain.init(
        @ptrCast(metal_layer),
        platform.window_size.width,
        platform.window_size.height,
    );
    defer renderer.deinit();

    if (platform.window) |window| {
        titlebar.customize(window);
        _ = webview.WebViewOverlay.init(window);
        drag_overlay.init(window);
    }

    while (try platform.pollEvents()) {
        if (platform.consumeSizeChanged()) {
            renderer.resize(platform.window_size.width, platform.window_size.height);
        }

        if (!renderer.render()) break;
    }
}
