# The Basics

## User-Provided Options

Use `b.option` to make the build script configurable to end users as well as
other projects that depend on the project as a package.

**`build.zig`**

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const windows = b.option(bool, "windows", "Target Microsoft Windows");

    const exe = b.addExecutable(.{
        .name = "example",
        .root_source_file = b.path("example.zig"),
        .target = target,
        .optimize = optimize,
    });

    if (windows) |w| {
        if (w) {
            exe.target = b.resolveTargetQuery(.{
                .cpu_arch = .x86_64,
                .os_tag = .windows,
            });
        }
    }

    b.installArtifact(exe);
}
```

**`example.zig`**

```zig
const std = @import("std");

pub fn main() !void {
    std.debug.print("Hello from example!\n", .{});
}
```

Please direct your attention to these lines:

```
Project-Specific Options:
  -Dwindows=[bool]             Target Microsoft Windows
```

This part of the help menu is auto-generated based on running the `build.zig` logic. Users
can discover configuration options of the build script this way.

## Standard Configuration Options

Previously, we used a boolean flag to indicate building for Windows. However, we can do
better.

Most projects want to provide the ability to change the target and optimization settings.
In order to encourage standard naming conventions for these options, Zig provides the
helper functions, `standardTargetOptions` and `standardOptimizeOption`.

Standard target options allows the person running `zig build` to choose what
target to build for. By default, any target is allowed, and no choice means to
target the host system. Other options for restricting supported target set are
available.

Standard optimization options allow the person running `zig build` to select
between `Debug`, `ReleaseSafe`, `ReleaseFast`, and `ReleaseSmall`. By default
none of the release options are considered the preferable choice by the build
script, and the user must make a decision in order to create a release build.

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

Now, our `--help` menu contains more items:

```
Project-Specific Options:
  -Dtarget=[string]            The CPU architecture, OS, and ABI to build for
  -Dcpu=[string]               Target CPU features to add or subtract
  -Doptimize=[enum]            Prioritize performance, safety, or binary size (-O flag)
                                 Supported Values:
                                   Debug
                                   ReleaseSafe
                                   ReleaseFast
                                   ReleaseSmall
```

It is entirely possible to create these options via `b.option` directly, but this
API provides a commonly used naming convention for these frequently used settings.

In our terminal output, observe that we passed `-Dtarget=x86_64-windows -Doptimize=ReleaseSmall`.
Compared to the first example, now we see different files in the installation prefix:

```
zig-out/
└── bin
    └── hello.exe
```

## Options for Conditional Compilation

To pass options from the build script and into the project's Zig code, use
the `Options` step.

**`app.zig`**

```zig
const config = @import("config");

pub fn main() !void {
    if (config.version < 100) {
        @compileError("too old");
    }
}
```

**`build.zig`**

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const options = b.addOptions();
    options.addOption(u32, "version", 123);

    const exe = b.addExecutable(.{
        .name = "app",
        .root_source_file = b.path("app.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addOptions("config", options);

    b.installArtifact(exe);
}
```

In this example, the data provided by `@import("config")` is comptime-known,
preventing the `@compileError` from triggering. If we had passed `-Dversion=0.2.3`
or omitted the option, then we would have seen the compilation of `app.zig` fail with
the "too old" error.

## Static Library

This build script creates a static library from Zig code, and then also an
executable from other Zig code that consumes it.

**`fizzbuzz.zig`**

```zig
pub fn fizzbuzz(n: u32) []const u8 {
    return switch (n % 15) {
        0 => "FizzBuzz",
        3, 6, 9, 12 => "Fizz",
        5, 10 => "Buzz",
        else => "",
    };
}

test "fizzbuzz" {
    const std = @import("std");
    try std.testing.expectEqualStrings("Fizz", fizzbuzz(3));
    try std.testing.expectEqualStrings("Buzz", fizzbuzz(5));
    try std.testing.expectEqualStrings("FizzBuzz", fizzbuzz(15));
}
```

**`demo.zig`**

```zig
const std = @import("std");
const fizzbuzz = @import("fizzbuzz");

pub fn main() !void {
    var i: u32 = 1;
    while (i <= 20) : (i += 1) {
        std.debug.print("{}\n", .{fizzbuzz.fizzbuzz(i)});
    }
}
```

**`build.zig`**

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const libfizzbuzz = b.addLibrary(.{
        .name = "fizzbuzz",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("fizzbuzz.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const exe = b.addExecutable(.{
        .name = "demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.linkLibrary(libfizzbuzz);

    b.installArtifact(libfizzbuzz);

    if (b.option(bool, "enable-demo", "install the demo too") orelse false) {
        b.installArtifact(exe);
    }
}
```

In this case, only the static library ends up being installed:

```
zig-out/
└── lib
    └── libfizzbuzz.a
```

However, if you look closely, the build script contains an option to also install the demo.
If we additionally pass `-Denable-demo`, then we see this in the installation prefix:

```
zig-out/
├── bin
│   └── demo
└── lib
    └── libfizzbuzz.a
```

Note that despite the unconditional call to `addExecutable`, the build system in fact
does not waste any time building the `demo` executable unless it is requested
with `-Denable-demo`, because the build system is based on a Directed Acyclic
Graph with dependency edges.

## Dynamic Library

Here we keep all the files the same from the [Static Library](#static-library) example, except
the `build.zig` file is changed.

**`build.zig`**

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const libfizzbuzz = b.addLibrary(.{
        .name = "fizzbuzz",
        .linkage = .dynamic,
        .version = .{ .major = 1, .minor = 2, .patch = 3 },
        .root_module = b.createModule(.{
            .root_source_file = b.path("fizzbuzz.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(libfizzbuzz);
}
```

**Output**

```
zig-out
└── lib
    ├── libfizzbuzz.so -> libfizzbuzz.so.1
    ├── libfizzbuzz.so.1 -> libfizzbuzz.so.1.2.3
    └── libfizzbuzz.so.1.2.3
```

As in the static library example, to make an executable link against it, use code like this:

```zig
exe.linkLibrary(libfizzbuzz);
```

## Testing

Individual files can be tested directly with `zig test foo.zig`, however, more
complex use cases can be solved by orchestrating testing via the build script.

When using the build script, unit tests are broken into two different steps in
the build graph, the **Compile** step and the **Run** step. Without a call to
`addRunArtifact`, which establishes a dependency edge between these two steps,
the unit tests will not be executed.

The _Compile_ step can be configured the same as any executable, library, or
object file, for example by [linking against system libraries](#linking-to-system-libraries),
setting target options, or adding additional compilation units.

The _Run_ step can be configured the same as any Run step, for example by
skipping execution when the host is not capable of executing the binary.

When using the build system to run unit tests, the build runner and the test
runner communicate via _stdin_ and _stdout_ in order to run multiple unit test
suites concurrently, and report test failures in a meaningful way without
having their output jumbled together. This is one reason why
[writing to _standard out_ in unit tests is problematic](https://github.com/ziglang/zig/issues/15091) -
it will interfere with this communication channel. On the flip side, this
mechanism will enable an upcoming feature, which is is the
[ability for a unit test to expect a _panic_](https://github.com/ziglang/zig/issues/1356).

**`main.zig`**

```zig
const std = @import("std");

pub fn main() !void {
    std.debug.print("Hello, world!\n", .{});
}

test "basic test" {
    try std.testing.expectEqual(1 + 1, 2);
}
```

**`build.zig`**

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "main",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
```

In this case it might be a nice adjustment to enable `skip_foreign_checks` for
the unit tests:

```diff
@@ -23,6 +23,7 @@
         });

         const run_unit_tests = b.addRunArtifact(unit_tests);
+        run_unit_tests.skip_foreign_checks = true;
         test_step.dependOn(&run_unit_tests.step);
     }
 }
```

**`build.zig`**

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "main",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    run_unit_tests.skip_foreign_checks = true;

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
```

## Linking to System Libraries

For satisfying library dependencies, there are two choices:

1. Provide these libraries via the Zig Build System
   (see [Package Management](#) and [Static Library](#static-library)).
2. Use the files provided by the host system.

For the use case of upstream project maintainers, obtaining these libraries via
the Zig Build System provides the least friction and puts the configuration
power in the hands of those maintainers. Everyone who builds this way will have
reproducible, consistent results as each other, and it will work on every
operating system and even support cross-compilation. Furthermore, it allows the
project to decide with perfect precision the exact versions of its entire
dependency tree it wishes to build against. This is expected to be the
generally preferred way to depend on external libraries.

However, for the use case of packaging software into repositories such as
Debian, Homebrew, or Nix, it is mandatory to link against system libraries. So,
build scripts must
[detect the build mode](https://github.com/ziglang/zig/issues/14281) and configure accordingly.

**`build.zig`**

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "example",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Link against system libraries
    exe.linkSystemLibrary("c");
    exe.linkSystemLibrary("SDL2");

    // For Linux systems, also link against math library
    if (target.result.os.tag == .linux) {
        exe.linkSystemLibrary("m");
    }

    b.installArtifact(exe);
}
```

Users of `zig build` may use `--search-prefix` to provide additional
directories that are considered "system directories" for the purposes of finding
static and dynamic libraries.
