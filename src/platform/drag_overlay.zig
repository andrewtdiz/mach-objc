const mach = @import("mach-objc");
const objc = mach.objc;
const app_kit = mach.app_kit;
const foundation = mach.foundation;
const core_graphics = mach.core_graphics;

var drag_window: ?*app_kit.Window = null;

const DragCallbacks = struct {
    pub fn mouseDown(block: *foundation.BlockLiteral(u8), event: *app_kit.Event) callconv(.c) void {
        _ = block;
        const window = drag_window orelse return;
        window.performWindowDragWithEvent(event);
    }
};

pub fn init(window: *app_kit.Window) void {
    drag_window = window;

    const content_view = window.contentView() orelse return;
    const bounds = objc.msgSend(content_view, "bounds", app_kit.Rect, .{});

    const drag_height: core_graphics.Float = 28;
    const origin_y: core_graphics.Float = bounds.size.height - drag_height;
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
