const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const module = b.addModule("mach-objc", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    module.linkSystemLibrary("objc", .{});

    // TODO: Maybe split this out into a separate module so we only link these in when needed.
    if (target.result.os.tag == .macos) {
        module.linkFramework("AppKit", .{});
        module.linkFramework("QuartzCore", .{});
        if (target.result.cpu.arch == .x86_64) {
            module.addAssemblyFile(b.path("MACHAppDelegate_x86_64_apple_macos12.s"));
            module.addAssemblyFile(b.path("MACHWindowDelegate_x86_64_apple_macos12.s"));
            module.addAssemblyFile(b.path("MACHView_x86_64_apple_macos12.s"));
        } else {
            module.addAssemblyFile(b.path("MACHAppDelegate_arm64_apple_macos12.s"));
            module.addAssemblyFile(b.path("MACHWindowDelegate_arm64_apple_macos12.s"));
            module.addAssemblyFile(b.path("MACHView_arm64_apple_macos12.s"));
        }
    } else {
        module.linkFramework("UIKit", .{});
        // TODO: Add iOS asm files once they are generated.
    }

    if (b.lazyDependency("xcode_frameworks", .{})) |dep| {
        module.addSystemFrameworkPath(dep.path("Frameworks"));
        module.addSystemIncludePath(dep.path("include"));
        module.addLibraryPath(dep.path("lib"));
    }

    const wgpu_native_dep = b.dependency("wgpu_native_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const generator_module = b.createModule(.{
        .root_source_file = b.path("generator.zig"),
        .target = target,
        .optimize = optimize,
    });
    const generator_exe = b.addExecutable(.{
        .name = "generator",
        .root_module = generator_module,
    });
    b.installArtifact(generator_exe);

    const window_example_module = b.createModule(.{
        .root_source_file = b.path("src/window_example.zig"),
        .target = target,
        .optimize = optimize,
    });
    const window_example = b.addExecutable(.{
        .name = "Clay Engine",
        .root_module = window_example_module,
    });
    if (target.result.os.tag == .macos) {
        window_example.root_module.linkFramework("Foundation", .{});
        window_example.root_module.linkFramework("Metal", .{});
        window_example.root_module.linkFramework("QuartzCore", .{});
        window_example.root_module.linkFramework("WebKit", .{});
    }
    const install_window_example = b.addInstallArtifact(window_example, .{});
    b.getInstallStep().dependOn(&install_window_example.step);
    window_example_module.addImport("mach-objc", module);

    const dvui_path = b.option([]const u8, "dvui-path", "Path to dvui (optional)");
    const dvui_module = if (dvui_path) |path| b.createModule(.{
        .root_source_file = b.path(b.fmt("{s}/src/dvui.zig", .{path})),
        .target = target,
        .optimize = optimize,
    }) else b.createModule(.{
        .root_source_file = b.path("src/dvui_stub.zig"),
        .target = target,
        .optimize = optimize,
    });
    window_example_module.addImport("dvui", dvui_module);

    const wgpu_path = b.option([]const u8, "wgpu-path", "Path to wgpu (optional)");
    const wgpu_module = if (wgpu_path) |path| b.createModule(.{
        .root_source_file = b.path(b.fmt("{s}/src/wgpu.zig", .{path})),
        .target = target,
        .optimize = optimize,
    }) else wgpu_native_dep.module("wgpu");
    window_example_module.addImport("wgpu", wgpu_module);

    const window_example_step = b.step("window-example", "Build the macOS window example");
    window_example_step.dependOn(&install_window_example.step);

    const run_window_example = b.addRunArtifact(window_example);
    const run_window_example_step = b.step("run-window-example", "Run the macOS window example");
    run_window_example_step.dependOn(&run_window_example.step);
}
