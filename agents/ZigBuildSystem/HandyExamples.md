# Handy Examples

## Build for multiple targets to make a release

In this example we're going to change some defaults when creating an `InstallArtifact` step in order to put the build for each target into a separate subdirectory inside the install path.

**`build.zig`**

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    // Define target platforms for the release
    const targets = [_]std.Target.Query{
        .{ .cpu_arch = .aarch64, .os_tag = .linux },
        .{ .cpu_arch = .aarch64, .os_tag = .macos },
        .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
        .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .musl },
        .{ .cpu_arch = .x86_64, .os_tag = .windows },
    };

    for (targets) |target_query| {
        const target = b.resolveTargetQuery(target_query);

        const exe = b.addExecutable(.{
            .name = "hello",
            .root_source_file = b.path("hello.zig"),
            .target = target,
            .optimize = optimize,
        });

        // Create install artifact with custom subdirectory
        const install = b.addInstallArtifact(exe, .{});

        // Override the install directory to be target-specific
        const target_name = target.result.zigTriple(b.allocator) catch "unknown";
        install.dest_dir = .{ .custom = target_name };
    }
}
```

**`hello.zig`**

```zig
const std = @import("std");

pub fn main() !void {
    std.debug.print("Hello from release build!\n", .{});
}
```

**Output**

```
zig-out
├── aarch64-linux
│   └── hello
├── aarch64-macos
│   └── hello
├── x86_64-linux-gnu
│   └── hello
├── x86_64-linux-musl
│   └── hello
└── x86_64-windows
    ├── hello.exe
    └── hello.pdb
```
