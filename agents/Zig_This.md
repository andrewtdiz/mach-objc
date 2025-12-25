`@This()` refers to the file’s root-level container type (every Zig file is an anonymous struct)

* `pub const Type = @This();` at file root aliases the **file’s anonymous container type**.
* That type has **no fields** (zero-sized). Use it for **namespacing + API surface**.
* Put state in a **separate inner struct**, and pass pointers to it into functions.

Inside any named struct, `const Self = @This();` aliases that struct type. This keeps method signatures decoupled from the concrete name and avoids copy-paste errors when the type is renamed.

### Example

```sidebar.zig
const std = @import("std");

pub const Sidebar = @This(); // the file's container type (zero-sized)

// Per-instance state lives in a real struct:
pub const State = struct {
    selected: Pane = .files,
};

pub const Pane = enum { files, tools, settings };

// Construct the “component” (often just return the ZST)
pub fn init() Sidebar {
    return .{};
}

// Create/own state explicitly (allocator if needed)
pub fn initState() State {
    return .{};
}

// Methods live at file scope; take the ZST and a *State
pub fn draw(_: Sidebar, state: *State) !void {
    // read/write per-instance data through state
    if (state.selected == .files) {
        // ...
    }
}

// Private helpers stay file-local
fn helper() void {}
```

### Why this architecture

* **Clear API**: `Sidebar` is the only exported “type”; funcs are namespaced by the file.
* **Stateless interface, explicit state**: Zero-size `Sidebar` for behavior; `State` for data.
* **Easy evolution**: Add/modify `State` fields without changing the public type name.
* **Test-friendly**: Create multiple `State` instances; reuse the same `Sidebar` value (`.{}`).

### Struct-local `@This()` example

```zig
const Self = @This();

texture: *wgpu.Texture,
view: *wgpu.TextureView,
width: u32,
height: u32,

pub fn init(device: *wgpu.Device, width: u32, height: u32) !Self { ... }
pub fn resize(self: *Self, device: *wgpu.Device, width: u32, height: u32) !void { ... }
pub fn readPixel(self: *Self, device: *wgpu.Device, queue: *wgpu.Queue, x: u32, y: u32) u32 { ... }
```

Use `Self` for both return types and receiver pointers so renaming `PickingBuffer` never breaks signatures. Keep the struct focused on the data it owns; delegate resource management to methods that operate on `*Self`.
