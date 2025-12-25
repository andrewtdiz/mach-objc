## Goal
Stop threading an allocator through every function by centralizing it and letting subsystems remember it.

## Minimal pattern

1) **Global allocator module**
```zig
// alloc.zig
const std = @import("std");

pub var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var ready = false;

pub fn init() std.mem.Allocator { ready = true; return gpa.allocator(); }
pub fn deinit() void { _ = gpa.deinit(); ready = false; }
pub fn allocator() std.mem.Allocator {
    if (!ready) @panic("global allocator not initialized");
    return gpa.allocator();
}
````

2. **Initialize once in `main`**

```zig
const Alloc = @import("alloc");

pub fn main() !void {
    _ = Alloc.init();        // sets up global GPA
    defer Alloc.deinit();

    try run();               // rest of app never passes an allocator
}
```

3. **Make types remember the allocator**

```zig
const Renderer = struct {
    allocator: std.mem.Allocator,
    pub fn init() !Renderer {
        return .{ .allocator = @import("alloc").allocator() };
    }
    pub fn deinit(self: *Renderer) void { /* use self.allocator if needed */ }
};
```

4. **Temp allocations: frame arena (optional)**

```zig
pub threadlocal var frame_arena: std.heap.ArenaAllocator = undefined;

pub fn beginFrame() void {
    frame_arena = std.heap.ArenaAllocator.init(@import("alloc").allocator());
}
pub fn endFrame() void { frame_arena.deinit(); }
pub fn frameAllocator() std.mem.Allocator { return frame_arena.allocator(); }
```

## Tradeoffs & guidance

* **Pros:** clean call sites, no allocator args everywhere.
* **Cons:** less testability/leak checking flexibility.
* **Testing:** swap `alloc.allocator()` to `std.testing.allocator` behind a build flag if needed.
* **If you don’t need leak checks:** you can use `const allocator = std.heap.c_allocator;` inside `alloc.zig` (no init/deinit).

```
