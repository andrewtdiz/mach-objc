# Generating Files

## Running System Tools

This version of hello world expects to find a `word.txt` file in the same path,
and we want to produce it at build-time by invoking a Zig program on a JSON file.

**`tools/words.json`**

```json
{
  "en": "world",
  "it": "mondo",
  "ja": "世界"
}
```

**`src/main.zig`**

```zig
const std = @import("std");

pub fn main() !void {
    const file = try std.fs.cwd().openFile("word.txt", .{});
    defer file.close();

    const content = try file.readToEndAlloc(std.heap.page_allocator, 1024);
    defer std.heap.page_allocator.free(content);

    std.debug.print("{s}", .{content});
}
```

**`tools/word_select.zig`**

```zig
const std = @import("std");

pub fn main() !void {
    const cwd = std.fs.cwd();

    const json_file = try cwd.openFile("tools/words.json", .{});
    defer json_file.close();

    const content = try json_file.readToEndAlloc(std.heap.page_allocator, 1024);
    defer std.heap.page_allocator.free(content);

    var parsed = try std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, content, .{});
    defer parsed.deinit();

    const words = parsed.value.object.get("en").?.string;

    const output_file = try cwd.createFile("word.txt", .{});
    defer output_file.close();

    try output_file.writeAll(words);
}
```

**`build.zig`**

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build the word selection tool
    const word_tool = b.addExecutable(.{
        .name = "word_select",
        .root_source_file = b.path("tools/word_select.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Run the word selection tool to generate word.txt
    const run_word_tool = b.addRunArtifact(word_tool);

    const exe = b.addExecutable(.{
        .name = "hello",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    // Make sure word.txt is generated before building the exe
    exe.step.dependOn(&run_word_tool.step);
}
```

**Output**

```
zig-out
├── hello
└── word.txt
```

## Producing Assets for `@embedFile`

This version of hello world wants to `@embedFile` an asset generated at build time,
which we're going to produce using a tool written in Zig.

**`tools/words.json`**

```json
{
  "en": "world",
  "it": "mondo",
  "ja": "世界"
}
```

**`src/main.zig`**

```zig
const std = @import("std");
const word = @embedFile("word.txt");

pub fn main() !void {
    std.debug.print("Hello, {s}!\n", .{word});
}
```

**`tools/word_select.zig`**

```zig
const std = @import("std");

pub fn main() !void {
    const cwd = std.fs.cwd();

    const json_file = try cwd.openFile("tools/words.json", .{});
    defer json_file.close();

    const content = try json_file.readToEndAlloc(std.heap.page_allocator, 1024);
    defer std.heap.page_allocator.free(content);

    var parsed = try std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, content, .{});
    defer parsed.deinit();

    const words = parsed.value.object.get("en").?.string;

    const output_file = try cwd.createFile("src/word.txt", .{});
    defer output_file.close();

    try output_file.writeAll(words);
}
```

**`build.zig`**

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build the word selection tool
    const word_tool = b.addExecutable(.{
        .name = "word_select",
        .root_source_file = b.path("tools/word_select.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Run the tool to generate word.txt
    const run_word_tool = b.addRunArtifact(word_tool);

    const exe = b.addExecutable(.{
        .name = "hello",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    // Make sure word.txt is generated before building the exe
    exe.step.dependOn(&run_word_tool.step);
}
```

**Output**

```
zig-out/
└── bin
    └── hello
```

## Generating Zig Source Code

This build file uses a Zig program to generate a Zig file and then exposes it
to the main program as a module dependency.

**`src/main.zig`**

```zig
const std = @import("std");
const generated = @import("generated");

pub fn main() !void {
    std.debug.print("Generated value: {}\n", .{generated.magic_number});
}
```

**`tools/generate_struct.zig`**

```zig
const std = @import("std");

pub fn main() !void {
    const cwd = std.fs.cwd();

    const output_file = try cwd.createFile("src/generated.zig", .{});
    defer output_file.close();

    const writer = output_file.writer();
    try writer.writeAll(
        \\pub const magic_number = 42;
        \\
        \\pub const greeting = "Hello from generated code!";
        \\
    );
}
```

**`build.zig`**

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build the code generation tool
    const gen_tool = b.addExecutable(.{
        .name = "generate_struct",
        .root_source_file = b.path("tools/generate_struct.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Run the tool to generate src/generated.zig
    const run_gen_tool = b.addRunArtifact(gen_tool);

    const exe = b.addExecutable(.{
        .name = "hello",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    // Make sure generated.zig is created before building the exe
    exe.step.dependOn(&run_gen_tool.step);
}
```

**Output**

```
zig-out/
└── bin
    └── hello
```

## Dealing With One or More Generated Files

The **WriteFiles** step provides a way to generate one or more files which
share a parent directory. The generated directory lives inside the local `.zig-cache`,
and each generated file is independently available as a `std.Build.LazyPath`.
The parent directory itself is also available as a `LazyPath`.

This API supports writing arbitrary strings to the generated directory as well
as copying files into it.

**`src/main.zig`**

```zig
const std = @import("std");
const generated_data = @embedFile("generated/data.txt");

pub fn main() !void {
    std.debug.print("Generated data: {s}\n", .{generated_data});
}
```

**`build.zig`**

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create a WriteFiles step
    const wf = b.addWriteFiles();

    // Add multiple files to the generated directory
    const data_file = wf.add("data.txt", "Hello from generated file!");
    const config_file = wf.add("config.txt", "setting=value\nother=123");

    // The generated directory path
    const generated_dir = wf.getDirectory();

    const exe = b.addExecutable(.{
        .name = "hello",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add the generated directory to the exe module's search paths
    exe.root_module.addAnonymousImport("generated", .{
        .root_source_file = data_file,
    });

    b.installArtifact(exe);
}
```

**Output**

```
zig-out/
└── project.tar.gz
```

## Mutating Source Files in Place

It is uncommon, but sometimes the case that a project commits generated files
into version control. This can be useful when the generated files are seldomly updated
and have burdensome system dependencies for the update process, but _only_ during the
update process.

For this, **WriteFiles** provides a way to accomplish this task. This is a feature that
[will be extracted from WriteFiles into its own Build Step](https://github.com/ziglang/zig/issues/14944)
in a future Zig version.

Be careful with this functionality; it should not be used during the normal
build process, but as a utility run by a developer with intention to update
source files, which will then be committed to version control. If it is done
during the normal build process, it will cause caching and concurrency bugs.

**`tools/proto_gen.zig`**

```zig
const std = @import("std");

pub fn main() !void {
    const cwd = std.fs.cwd();

    const output_file = try cwd.createFile("src/protocol.zig", .{});
    defer output_file.close();

    const writer = output_file.writer();
    try writer.writeAll(
        \\pub const Protocol = struct {
        \\    pub const version = 1;
        \\    pub const magic_number = 0xDEADBEEF;
        \\    pub const max_message_size = 4096;
        \\};
        \\
        \\pub const MessageType = enum {
        \\    hello,
        \\    goodbye,
        \\    data,
        \\};
        \\
    );
}
```

**`src/main.zig`**

```zig
const std = @import("std");
const protocol = @import("protocol");

pub fn main() !void {
    std.debug.print("Protocol version: {}\n", .{protocol.Protocol.version});
    std.debug.print("Magic number: 0x{X}\n", .{protocol.Protocol.magic_number});
}
```

**`src/protocol.zig`**

```zig
// This file is generated by tools/proto_gen.zig
// Do not edit manually - run `zig build update-protocol` to regenerate

pub const Protocol = struct {
    pub const version = 1;
    pub const magic_number = 0xDEADBEEF;
    pub const max_message_size = 4096;
};

pub const MessageType = enum {
    hello,
    goodbye,
    data,
};
```

**`build.zig`**

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "hello",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    // Build the protocol generation tool
    const proto_gen = b.addExecutable(.{
        .name = "proto_gen",
        .root_source_file = b.path("tools/proto_gen.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Create a step to update the protocol file
    const update_proto_cmd = b.addRunArtifact(proto_gen);
    const update_proto_step = b.step("update-protocol", "Regenerate src/protocol.zig");
    update_proto_step.dependOn(&update_proto_cmd.step);
}
```

```=html
<pre><code class="shell">$ zig build update-protocol --summary all
<span class="sgr-36m">Build Summary:</span> 4/4 steps succeeded
update-protocol<span class="sgr-32m"> success</span>
└─ WriteFile<span class="sgr-32m"> success</span>
   └─ run proto_gen (protocol.zig)<span class="sgr-32m"> success</span><span class="sgr-2m"> 401us</span><span class="sgr-2m"> MaxRSS:1M</span>
      └─ zig build-exe proto_gen Debug native<span class="sgr-32m"> success</span><span class="sgr-2m"> 1s</span><span class="sgr-2m"> MaxRSS:183M</span>
</code></pre>
```

After running this command, `src/protocol.zig` is updated in place.

