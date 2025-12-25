const mach = @import("main.zig");
const app_kit = mach.app_kit;
const foundation = mach.foundation;
const objc = mach.objc;

pub fn main() !void {
    const pool = objc.autoreleasePoolPush();
    defer objc.autoreleasePoolPop(pool);

    const app = app_kit.Application.sharedApplication();
    _ = app.setActivationPolicy(app_kit.ApplicationActivationPolicyRegular);

    const rect = app_kit.Rect{
        .origin = .{ .x = 100, .y = 100 },
        .size = .{ .width = 800, .height = 600 },
    };

    const style =
        app_kit.WindowStyleMaskTitled |
        app_kit.WindowStyleMaskClosable |
        app_kit.WindowStyleMaskResizable |
        app_kit.WindowStyleMaskMiniaturizable;

    const window = app_kit.Window
        .alloc()
        .initWithContentRect_styleMask_backing_defer_screen(
        rect,
        style,
        app_kit.BackingStoreBuffered,
        false,
        null,
    );

    const title = foundation.String.stringWithUTF8String("Mach ObjC Window");
    window.setTitle(title);
    window.center();
    window.makeKeyAndOrderFront(null);

    app.activateIgnoringOtherApps(true);
    app.run();
}
