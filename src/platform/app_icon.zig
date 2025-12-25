const mach = @import("mach-objc");
const objc = mach.objc;
const app_kit = mach.app_kit;
const foundation = mach.foundation;

pub fn set(path: [:0]const u8) void {
    const ns_path = foundation.String.stringWithUTF8String(path);
    const image = app_kit.Image.alloc().initWithContentsOfFile(ns_path) orelse return;
    defer image.release();

    const ns_app = app_kit.Application.sharedApplication();
    objc.msgSend(ns_app, "setApplicationIconImage:", void, .{image});
}
