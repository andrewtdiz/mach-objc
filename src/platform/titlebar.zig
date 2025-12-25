const mach = @import("mach-objc");
const app_kit = mach.app_kit;
const core_graphics = mach.core_graphics;

pub fn customize(window: *app_kit.Window) void {
    window.setTitlebarAppearsTransparent(true);
    window.setTitleVisibility(app_kit.WindowTitleHidden);
    window.setBackgroundColor(app_kit.Color.clearColor());
    window.setMovableByWindowBackground(true);

    repositionTrafficLights(window);
}

fn repositionTrafficLights(window: *app_kit.Window) void {
    const traffic_light_x: core_graphics.Float = 12;
    const button_spacing: core_graphics.Float = 20;

    if (window.standardWindowButton(app_kit.WindowButtonClose)) |close_btn| {
        if (mach.objc.msgSend(close_btn, "superview", ?*app_kit.View, .{})) |container| {
            mach.objc.msgSend(container, "layoutSubtreeIfNeeded", void, .{});
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
