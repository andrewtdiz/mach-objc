## Mac platform responsibilities
- [x] Window + event loop: `NSApplication`, `NSWindow`, and an `NSView` that owns the Metal layer; `pollEvents` drains the Cocoa event queue.
- [x] Input: translate `NSEvent` key/mouse events into `PlatformKeyEvent` and `PlatformTextEvent`, update `mouse_state`, and feed DVUI via `UIEventSink`.
- [x] Cursor: map `input.CursorType` to `NSCursor`, including hide/show support.
- [x] Clipboard: `NSPasteboard`.
- [ ] Window control: minimize, zoom, close, and window drag; optional custom resize behavior.
- [ ] Tray icon: optional `NSStatusBar` implementation or a no-op guarded by a feature flag.
