const mach = @import("mach-objc");
const objc = mach.objc;
const app_kit = mach.app_kit;
const foundation = mach.foundation;

pub const WebViewOverlay = @This();

pub const default_html: [:0]const u8 =
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

web_view: *app_kit.WebView,

pub fn init(window: *app_kit.Window) ?WebViewOverlay {
    const content_view = window.contentView() orelse return null;
    const bounds = objc.msgSend(content_view, "bounds", app_kit.Rect, .{});

    const configuration = app_kit.WebViewConfiguration.allocInit();
    const web_view = app_kit.WebView.alloc().initWithFrame_configuration(bounds, configuration);
    configuration.release();

    const web_view_base = web_view.as(app_kit.View);
    web_view_base.setAutoresizingMask(app_kit.ViewWidthSizable | app_kit.ViewHeightSizable);

    const html_string = foundation.String.stringWithUTF8String(default_html);
    web_view.loadHTMLString_baseURL(html_string, null);

    web_view.setOpaque(false);

    const draws_background_key = foundation.String.stringWithUTF8String("drawsBackground");
    const draws_background_value = foundation.Number.numberWithBool(false);
    web_view.setValue_forKey(@ptrCast(draws_background_value), draws_background_key);

    content_view.addSubView(@ptrCast(web_view));

    return .{ .web_view = web_view };
}

pub fn deinit(self: *WebViewOverlay) void {
    self.web_view.release();
}
