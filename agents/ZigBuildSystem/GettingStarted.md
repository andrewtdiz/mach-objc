# Getting Started

## Simple Executable

This build script creates an executable from a Zig file that contains a public `main` function definition.

**`hello.zig`**

```zig
const std = @import("std");

pub fn main() !void {
    std.debug.print("Hello, world!\n", .{});
}
```

**`build.zig`**

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "hello",
        .root_source_file = b.path("hello.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
```

## Installing Build Artifacts

The Zig build system, like most build systems, is based on modeling the project as a directed acyclic graph (DAG) of steps, which are independently and concurrently run.

By default, the main step in the graph is the **Install** step, whose purpose
is to copy build artifacts into their final resting place. The Install step
starts with no dependencies, and therefore nothing will happen when `zig build`
is run. A project's build script must add to the set of things to install, which
is what the `installArtifact` function call does above.

**Output**

```
├── build.zig
├── hello.zig
├── .zig-cache
└── zig-out
    └── bin
        └── hello
```

There are two generated directories in this output: `.zig-cache` and `zig-out`. The first one contains files that will make subsequent builds faster, but these files are not intended to be checked into source-control and this directory can be completely deleted at any time with no consequences.

The second one, `zig-out`, is an "installation prefix". This maps to the standard file system hierarchy concept. This directory is not chosen by the project, but by the user of `zig build` with the `--prefix` flag (`-p` for short).

You, as the project maintainer, pick what gets put in this directory, but the user chooses where to install it in their system. The build script cannot hardcode output paths because this would break caching, concurrency, and composability, as well as annoy the final user.

## Adding a Convenience Step for Running the Application

It is common to add a **Run** step to provide a way to run one's main application directly
from the build command.

**`hello.zig`**

```zig
const std = @import("std");

pub fn main() !void {
    std.debug.print("Hello, world!\n", .{});
}
```

**`build.zig`**

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "hello",
        .root_source_file = b.path("hello.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
```
