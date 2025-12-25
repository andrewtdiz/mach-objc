Here’s the up-to-date, Zig-0.16-style way to JSON-serialize (“stringify”) and parse (“deserialize”) values — plus small, copy-pasteable examples you can hand to a coding LLM.

Zig’s JSON API exposes:

* High-level stringify functions:

  * `std.json.stringify(value, options, writer)` (stream to any writer)
  * `std.json.stringifyAlloc(allocator, value, options) []const u8` (return an owned slice) ([ratfactor.com][1])
* High-level parse functions:

  * `std.json.parseFromSlice(T, allocator, bytes, options) -> std.json.Parsed(T)` (you must call `deinit()`) ([ratfactor.com][2])
* Useful options for stringify (selected):

  * `.whitespace = .minified | .indent_2 | .indent_tab | …`
  * `.emit_null_optional_fields = bool`
  * `.emit_strings_as_arrays = bool` (treat `[]u8` as `[u8]` array instead of UTF-8 string)
  * `.escape_unicode = bool`
  * `.emit_nonportable_numbers_as_strings = bool` ([ratfactor.com][1])

> The “latest” docs you linked point at master (`#std.json.Stringify`), which matches these APIs; the same names and options appear in the stdlib sources used by 0.16-dev. ([ziglang.org][3])

---

# Minimal, memory-safe recipes

## 1) Stringify any `struct` to an owned JSON string

```zig
const std = @import("std");

const Person = struct {
    name: []const u8,
    age: u16,
    // Optionals that are null can be omitted via options (see below)
    nickname: ?[]const u8 = null,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const p = Person{ .name = "Ava", .age = 29 };

    // One-liner that returns owned memory (you free it):
    const json = try std.json.stringifyAlloc(alloc, p, .{ .whitespace = .minified });
    defer alloc.free(json);

    try std.io.getStdOut().writer().writeAll(json);
}
```

Why this is “safe”: no hidden allocations; you own the returned slice and free it. If you need pretty output, set `.whitespace = .indent_2`. Options above are taken directly from `StringifyOptions`. ([ratfactor.com][1])

## 2) Stream to a writer (no big temporary)

```zig
const std = @import("std");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var buf = std.ArrayList(u8).init(arena.allocator());
    defer buf.deinit();

    const payload = .{ .lat = 51.5, .long = -0.12 };

    try std.json.stringify(payload, .{ .whitespace = .indent_2 }, buf.writer());
    // buf.items now holds the JSON; print or send it
    try std.io.getStdOut().writer().writeAll(buf.items);
}
```

This matches the “writer”-based pattern used across std; `stringify` accepts any writer. ([ratfactor.com][2])

## 3) Parse JSON into a typed `struct`

```zig
const std = @import("std");

const Person = struct {
    name: []const u8,
    age: u16,
    nickname: ?[]const u8 = null, // missing -> default; present null -> null
};

pub fn main() !void {
    const input =
        \\{ "name": "Ava", "age": 29 }
    ;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    // High-level, typed parse. Owns any allocated strings; must call deinit().
    const parsed = try std.json.parseFromSlice(Person, arena.allocator(), input, .{});
    defer parsed.deinit();

    const p = parsed.value;
    std.debug.print("name={s} age={d}\n", .{ p.name, p.age });
}
```

This is the canonical `parseFromSlice` pattern; `parsed.deinit()` frees anything the parser allocated. ([zig.guide][4])

---

# Useful knobs (handy for an LLM prompt)

* **Omit null optionals** when stringifying:

  ```zig
  try std.json.stringify(v, .{ .emit_null_optional_fields = false }, w);
  ```

  ([ratfactor.com][1])

* **Force `[]u8` as array of numbers** (instead of UTF-8 string):

  ```zig
  try std.json.stringify(v, .{ .emit_strings_as_arrays = true }, w);
  ```

  ([ratfactor.com][1])

* **Escape all non-ASCII**:

  ```zig
  try std.json.stringify(v, .{ .escape_unicode = true }, w);
  ```

  ([ratfactor.com][1])

* **Custom per-type serialization**: add a `jsonStringify` method on your type:

  ```zig
  const std = @import("std");
  const OrderId = struct {
      id: u64,
      pub fn jsonStringify(self: *@This(), jw: anytype) !void {
          // Emit as string "ord-<id>"
          try jw.write("ord-" ++ std.fmt.comptimePrint("{d}", .{self.id}));
      }
  };
  ```

  When present, `std.json.stringify` will call this instead of the default field-by-field logic. The `jw` parameter is a `std.json.WriteStream`. ([ratfactor.com][1])

* **Diagnostics / max depth**: prefer `stringifyArbitraryDepth` or `writeStreamArbitraryDepth` during debugging — enables safety checks for arbitrarily deep trees. In release-fast/small, these checks are compiled out. ([ratfactor.com][1])

---

# End-to-end “arbitrary struct → JSON → struct” (tight, safe)

```zig
const std = @import("std");

const Config = struct {
    host: []const u8,
    port: u16 = 8080,          // defaulted field tolerated if missing
    tls: ?bool = null,         // optional
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const A = arena.allocator();

    // 1) Create a struct and stringify to owned bytes:
    const cfg = Config{ .host = "example.com", .tls = true };
    const out = try std.json.stringifyAlloc(A, cfg, .{ .whitespace = .minified });
    defer A.free(out);

    // 2) Parse back (typed) and auto-free on scope exit:
    const parsed = try std.json.parseFromSlice(Config, A, out, .{});
    defer parsed.deinit();

    const roundtrip = parsed.value;
    std.debug.print("{s}:{d} tls={any}\n", .{ roundtrip.host, roundtrip.port, roundtrip.tls });
}
```

This uses only owned memory (arena) and predictable lifetimes: free the string with `A.free`, and `parsed.deinit()` releases parser allocations. ([ratfactor.com][1])

---

# Notes specific to **0.16-dev**

* The signatures/options above match the **current master** used for 0.16 development; issues and milestones reference 0.16.0-dev and the same APIs (`StringifyOptions`, `writeStream`, `stringifyAlloc`, etc.). ([GitHub][5])
* Some community examples for 0.15/0.16 show the exact writer pattern (`std.ArrayList(u8).init(alloc); … stringify(value, .{}, list.writer())`). It’s the idiomatic way to capture bytes without extra copies. ([Reddit][6])

---

# Quick “prompt” you can hand to a coding LLM

> **Task:** In Zig 0.16, JSON-serialize any `struct` with `std.json.stringify` (or `stringifyAlloc`) and parse it back with `std.json.parseFromSlice`.
> **Constraints:** No hidden allocations; own and free all memory; avoid large temporaries; prefer stream-to-writer.
> **Steps:**
>
> 1. Allocate an `ArrayList(u8)` or call `stringifyAlloc(alloc, value, .{ .whitespace = .minified })` and remember to `alloc.free` it.
> 2. For writer streaming: `var list = std.ArrayList(u8).init(alloc); defer list.deinit(); try std.json.stringify(value, .{ .emit_null_optional_fields = false }, list.writer());`
> 3. To parse: `const parsed = try std.json.parseFromSlice(T, alloc, bytes, .{}); defer parsed.deinit(); const v = parsed.value;`.
> 4. To customize a type’s JSON, implement `pub fn jsonStringify(self: *@This(), jw: anytype) !void` and write fields/tokens via `jw`.
> 5. Prefer arenas for request-scoped work; always `deinit()`/`free()` at the end of the scope.
