const std = @import("std");
const builtin = @import("builtin");

const wgpu = @import("wgpu");

fn logUncapturedError(
    _: ?*wgpu.Device,
    error_type: wgpu.ErrorType,
    message: wgpu.StringView,
    _: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) void {
    std.debug.print("[wgpu] {s}: {s}\n", .{ @tagName(error_type), message.toSlice() orelse "" });
}

fn logDeviceLost(
    _: *const ?*wgpu.Device,
    reason: wgpu.DeviceLostReason,
    message: wgpu.StringView,
    userdata1: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) void {
    if (userdata1) |ptr| {
        const flag: *bool = @ptrCast(@alignCast(ptr));
        flag.* = true;
    }
    std.debug.print("[wgpu] device lost: {s} ({s})\n", .{ @tagName(reason), message.toSlice() orelse "" });
}

/// Surface descriptor source for Windows
var surface_source_windows: wgpu.SurfaceSourceWindowsHWND = undefined;
var surface_source_metal_layer: wgpu.SurfaceSourceMetalLayer = undefined;

/// WebGPU resources for 2D game rendering
pub const SwapChain = struct {
    instance: *wgpu.Instance,
    adapter: *wgpu.Adapter,
    device: *wgpu.Device,
    queue: *wgpu.Queue,
    surface: *wgpu.Surface,
    format: wgpu.TextureFormat,
    present_mode: wgpu.PresentMode,
    alpha_mode: wgpu.CompositeAlphaMode,
    width: u32,
    height: u32,
    /// Set when surface needs reconfiguration (suboptimal, outdated, lost)
    needs_reconfigure: bool = false,

    /// Initialize WebGPU swap chain with native window handle
    /// hwnd: Native window handle (HWND on Windows)
    pub fn init(hwnd: *anyopaque, width: u32, height: u32, device_lost_flag: *bool) !SwapChain {
        const descriptor = try surfaceDescriptor(hwnd);

        const instance = wgpu.Instance.create(null) orelse return error.InstanceCreationFailed;
        errdefer instance.release();

        const surface = instance.createSurface(&descriptor) orelse return error.SurfaceCreationFailed;
        errdefer surface.release();

        var adapter_request = instance.requestAdapterSync(&wgpu.RequestAdapterOptions{
            .compatible_surface = surface,
            .power_preference = wgpu.PowerPreference.undefined,
            .force_fallback_adapter = @intFromBool(false),
            .backend_type = if (builtin.os.tag == .windows) wgpu.BackendType.d3d12 else wgpu.BackendType.@"undefined",
        }, 0);
        if (adapter_request.status != .success and builtin.os.tag == .windows) {
            adapter_request = instance.requestAdapterSync(&wgpu.RequestAdapterOptions{
                .compatible_surface = surface,
                .power_preference = wgpu.PowerPreference.undefined,
                .force_fallback_adapter = @intFromBool(false),
            }, 0);
        }
        const adapter = switch (adapter_request.status) {
            .success => adapter_request.adapter.?,
            else => return error.NoAdapter,
        };
        errdefer adapter.release();

        // Get surface capabilities
        var caps = std.mem.zeroes(wgpu.SurfaceCapabilities);
        const surface_caps = surface.getCapabilities(adapter, &caps);
        if (surface_caps != .success) {
            return error.FailedToGetSurfaceCapabilities;
        }
        defer caps.freeMembers();

        // Log adapter info
        var props = std.mem.zeroes(wgpu.AdapterInfo);
        _ = adapter.getInfo(&props);
        std.debug.print("GPU adapter: {s} backend={s}\n", .{
            props.device.toSlice() orelse "unknown",
            @tagName(props.backend_type),
        });
        defer props.freeMembers();

        // Request device with minimal limits
        // Get default limits from adapter
        var supported_limits = std.mem.zeroes(wgpu.Limits);
        _ = adapter.getLimits(&supported_limits);

        const device_request = adapter.requestDeviceSync(instance, &wgpu.DeviceDescriptor{
            .label = wgpu.StringView.fromSlice("2D Game Device"),
            .required_limits = &supported_limits,
            .uncaptured_error_callback_info = wgpu.UncapturedErrorCallbackInfo{
                .callback = logUncapturedError,
            },
            .device_lost_callback_info = wgpu.DeviceLostCallbackInfo{
                .mode = wgpu.CallbackMode.allow_process_events,
                .callback = logDeviceLost,
                .userdata1 = device_lost_flag,
            },
        }, 0);
        const device = switch (device_request.status) {
            .success => device_request.device.?,
            else => return error.NoDevice,
        };
        errdefer device.release();

        const queue = device.getQueue() orelse return error.NoQueue;

        // Configure surface
        const format = if (caps.format_count > 0) caps.formats[0] else wgpu.TextureFormat.bgra8_unorm_srgb;
        const present_mode = pickPresentMode(caps.present_modes[0..caps.present_mode_count]);
        const alpha_mode = pickAlphaMode(caps.alpha_modes[0..caps.alpha_mode_count]);

        surface.configure(&wgpu.SurfaceConfiguration{
            .device = device,
            .format = format,
            .usage = wgpu.TextureUsages.render_attachment,
            .width = if (width == 0) 1 else width,
            .height = if (height == 0) 1 else height,
            .present_mode = present_mode,
            .alpha_mode = alpha_mode,
        });

        return .{
            .instance = instance,
            .adapter = adapter,
            .device = device,
            .queue = queue,
            .surface = surface,
            .format = format,
            .present_mode = present_mode,
            .alpha_mode = alpha_mode,
            .width = width,
            .height = height,
        };
    }

    pub fn deinit(self: *SwapChain) void {
        self.surface.release();
        self.queue.release();
        self.device.release();
        self.adapter.release();
        self.instance.release();
    }

    pub fn resize(self: *SwapChain, width: u32, height: u32) void {
        if (width == 0 or height == 0) return;
        self.surface.configure(&wgpu.SurfaceConfiguration{
            .device = self.device,
            .format = self.format,
            .usage = wgpu.TextureUsages.render_attachment,
            .width = width,
            .height = height,
            .present_mode = self.present_mode,
            .alpha_mode = self.alpha_mode,
        });
        self.width = width;
        self.height = height;
    }

    pub const AcquireError = error{
        Timeout,
        Outdated,
        Lost,
        OutOfMemory,
        DeviceLost,
        TextureError,
        TextureUnavailable,
    };

    /// Acquire a frame for rendering. This is the guardrail that prevents
    /// queue.submit from running on a lost/invalid device.
    pub fn acquireFrame(self: *SwapChain) AcquireError!Frame {
        var surface_texture: wgpu.SurfaceTexture = undefined;
        self.surface.getCurrentTexture(&surface_texture);
        const status = surface_texture.status;
        const maybe_texture = surface_texture.texture;

        const texture = texture: {
            switch (status) {
                .success_optimal => {},
                .success_suboptimal => {
                    // Surface still usable but should reconfigure soon
                    self.needs_reconfigure = true;
                },
                .timeout => {
                    if (maybe_texture) |tex| tex.release();
                    return AcquireError.Timeout;
                },
                .outdated => {
                    self.needs_reconfigure = true;
                    if (maybe_texture) |tex| tex.release();
                    return AcquireError.Outdated;
                },
                .lost => {
                    self.needs_reconfigure = true;
                    if (maybe_texture) |tex| tex.release();
                    return AcquireError.Lost;
                },
                .out_of_memory => {
                    if (maybe_texture) |tex| tex.release();
                    return AcquireError.OutOfMemory;
                },
                .device_lost => {
                    std.debug.print("[wgpu] Surface reported device_lost during getCurrentTexture\n", .{});
                    if (maybe_texture) |tex| tex.release();
                    return AcquireError.DeviceLost;
                },
                .@"error" => {
                    if (maybe_texture) |tex| tex.release();
                    return AcquireError.TextureError;
                },
            }
            if (maybe_texture) |tex| break :texture tex;
            return AcquireError.TextureUnavailable;
        };

        const view = texture.createView(null) orelse {
            texture.release();
            return AcquireError.TextureUnavailable;
        };

        return Frame{
            .texture = texture,
            .view = view,
            .surface = self.surface,
        };
    }
};

pub const Frame = struct {
    texture: *wgpu.Texture,
    view: *wgpu.TextureView,
    surface: *wgpu.Surface,

    pub fn release(self: *Frame) void {
        self.view.release();
        self.texture.release();
    }

    pub fn present(self: *Frame) void {
        _ = self.surface.present();
    }
};

/// Get surface descriptor from native window handle
fn surfaceDescriptor(hwnd: *anyopaque) !wgpu.SurfaceDescriptor {
    return switch (builtin.os.tag) {
        .windows => {
            const hinstance = std.os.windows.kernel32.GetModuleHandleW(null) orelse return error.MissingInstanceHandle;
            surface_source_windows = .{
                .hinstance = @ptrCast(hinstance),
                .hwnd = hwnd,
            };
            return wgpu.SurfaceDescriptor{
                .next_in_chain = @ptrCast(&surface_source_windows),
                .label = wgpu.StringView.fromSlice("2D Game Surface"),
            };
        },
        .macos => {
            surface_source_metal_layer = .{
                .layer = hwnd,
            };
            return wgpu.SurfaceDescriptor{
                .next_in_chain = @ptrCast(&surface_source_metal_layer),
                .label = wgpu.StringView.fromSlice("2D Game Surface"),
            };
        },
        else => error.UnsupportedPlatform,
    };
}

fn containsPresentMode(modes: []const wgpu.PresentMode, needle: wgpu.PresentMode) bool {
    for (modes) |mode| {
        if (mode == needle) return true;
    }
    return false;
}

fn pickPresentMode(modes: []const wgpu.PresentMode) wgpu.PresentMode {
    if (modes.len == 0) return .fifo;
    if (containsPresentMode(modes, .fifo)) return .fifo;
    return modes[0];
}

fn pickAlphaMode(modes: []const wgpu.CompositeAlphaMode) wgpu.CompositeAlphaMode {
    if (modes.len == 0) return .@"opaque";
    return modes[0];
}
