# Mac Architecture

## Goals
- Build both the `ClayEngine` executable and the `clay_engine` shared library on macOS with the same Bun FFI flow.
- Keep engine core modules (render, audio, physics, UI command processing) unchanged where possible.

## Windows-only surfaces to replace or gate
- `src/windows/` windowing, input, cursor, shell, and message pump.
- `deps/webview/` WebView2 bindings and `deps/webview/webview.cc`.
- Win32-specific imports in `src/engine/exports/input.zig` and `src/webview/host.zig`.
- Win32 build logic in `build.zig` (WebView2 paths, Win32 libraries, `.rc` resources).
- `src/utils/subprocess.zig` uses `where.exe` for Bun discovery.

## Platform layer plan
- Add a `src/platform/` module that selects `WindowsPlatform` or `MacPlatform` at compile time.
- Keep the same surface used today: `window_size`, `mouse_state`, `keyEvents`, `textEvents`, `pollEvents`, `setResizeHook`, `setUIEventSink`, `setCursor`, clipboard, and window commands.
- Preserve explicit lifecycles: `create`, `init`, `deinit`, `destroy`.

## Mac platform responsibilities
- Window + event loop: `NSApplication`, `NSWindow`, and an `NSView` that owns the Metal layer; `pollEvents` drains the Cocoa event queue.
- Input: translate `NSEvent` key/mouse events into `PlatformKeyEvent` and `PlatformTextEvent`, update `mouse_state`, and feed DVUI via `UIEventSink`.
- Cursor: map `input.CursorType` to `NSCursor`, including hide/show support.
- Clipboard: `NSPasteboard`.
- Window control: minimize, zoom, close, and window drag; optional custom resize behavior.
- Tray icon: optional `NSStatusBar` implementation or a no-op guarded by a feature flag.

## WebGPU surface on macOS
- Refactor `src/engine/render/game/swap_chain.zig` to accept a `wgpu.SurfaceDescriptor` from the platform instead of assuming an HWND.
- Mac platform should expose `getWgpuSurfaceDescriptor` backed by a `CAMetalLayer` or `NSView` handle per the `wgpu` API.
- Use the Metal backend for adapter selection on macOS.

## Webview on macOS
- Replace Windows-only `deps/webview` with per-OS implementations that keep the same Zig API (`WebView.init`, `resize`, `focus`, `eval`, `setMessageCallback`, `processEventsAndWait`).
- Mac backend should use `WKWebView` with a script message handler to forward JSON messages used by `src/webview/host.zig`.
- `processEventsAndWait` can be a no-op if the Cocoa run loop is already driving events.

## Build system changes
- Gate Win32-only dependencies in `build.zig` (`zigwin32`, WebView2 include paths, `winwebview` static lib, WebView2Loader.dll install, `.rc` resources, Win32 system libs).
- Add a macOS WebView build step for ObjC/ObjC++ sources and link `Cocoa`, `WebKit`, `QuartzCore`, and `Metal`.
- Ensure `clay_engine` builds as a `.dylib` and the `ClayEngine` executable builds as a standard macOS binary (optional `.app` bundle).
- Make WebView tests OS-specific; `build.zig` currently references `src/webview.zig`, which does not exist.

## Runtime adjustments
- `src/utils/subprocess.zig`: replace `where.exe` with `which` or `BUN_INSTALL` on macOS.
- `src/engine/exports/input.zig`: move Win32 key polling behind the platform or provide a macOS key state query.
- `src/webview/host.zig`: switch to platform-agnostic types and drop Win32 child subclass logic on macOS.

## Bring-up sequence
1. Build core without webview (Mac platform + WebGPU surface + input).
2. Render and present a frame.
3. Wire shared-memory input state and DVUI events.
4. Add the WKWebView backend and window-control messaging.
