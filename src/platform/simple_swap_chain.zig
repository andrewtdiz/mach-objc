const std = @import("std");
const wgpu = @import("wgpu");
const swap_chain = @import("../wgpu/swap_chain.zig");

// Animated RGB gradient shader
const shader_code =
    \\@group(0) @binding(0) var<uniform> time: f32;
    \\
    \\struct VertexOutput {
    \\    @builtin(position) position: vec4<f32>,
    \\    @location(0) uv: vec2<f32>,
    \\};
    \\
    \\@vertex
    \\fn vs_main(@builtin(vertex_index) vertex_index: u32) -> VertexOutput {
    \\    var positions = array<vec2<f32>, 3>(
    \\        vec2<f32>(-1.0, -1.0),
    \\        vec2<f32>(3.0, -1.0),
    \\        vec2<f32>(-1.0, 3.0),
    \\    );
    \\    var uvs = array<vec2<f32>, 3>(
    \\        vec2<f32>(0.0, 1.0),
    \\        vec2<f32>(2.0, 1.0),
    \\        vec2<f32>(0.0, -1.0),
    \\    );
    \\    var output: VertexOutput;
    \\    output.position = vec4<f32>(positions[vertex_index], 0.0, 1.0);
    \\    output.uv = uvs[vertex_index];
    \\    return output;
    \\}
    \\
    \\@fragment
    \\fn fs_main(input: VertexOutput) -> @location(0) vec4<f32> {
    \\    let uv = input.uv;
    \\    let r = 0.5 + 0.5 * sin(time + uv.x * 3.14159);
    \\    let g = 0.5 + 0.5 * sin(time * 1.3 + uv.y * 3.14159 + 2.094);
    \\    let b = 0.5 + 0.5 * sin(time * 0.7 + (uv.x + uv.y) * 1.5 + 4.188);
    \\    return vec4<f32>(r, g, b, 1.0);
    \\}
;

pub const SimpleSwapChain = struct {
    swapchain: swap_chain.SwapChain,
    pipeline: *wgpu.RenderPipeline,
    bind_group: *wgpu.BindGroup,
    time_buffer: *wgpu.Buffer,
    start_time: i128,
    device_lost: bool,

    pub fn init(metal_layer: *anyopaque, width: u32, height: u32) !SimpleSwapChain {
        var device_lost = false;
        var swapchain = try swap_chain.SwapChain.init(metal_layer, width, height, &device_lost);
        errdefer swapchain.deinit();

        // Create shader module
        const shader_module = swapchain.device.createShaderModule(&wgpu.ShaderModuleDescriptor{
            .label = wgpu.StringView.fromSlice("gradient-shader"),
            .next_in_chain = @ptrCast(&wgpu.ShaderSourceWGSL{
                .code = wgpu.StringView.fromSlice(shader_code),
            }),
        }) orelse return error.ShaderCreationFailed;
        defer shader_module.release();

        // Create time uniform buffer
        const time_buffer = swapchain.device.createBuffer(&wgpu.BufferDescriptor{
            .label = wgpu.StringView.fromSlice("time-buffer"),
            .size = @sizeOf(f32),
            .usage = wgpu.BufferUsages.uniform | wgpu.BufferUsages.copy_dst,
            .mapped_at_creation = @intFromBool(false),
        }) orelse return error.BufferCreationFailed;
        errdefer time_buffer.release();

        // Create bind group layout
        var bind_group_layout_entries = [_]wgpu.BindGroupLayoutEntry{
            .{
                .binding = 0,
                .visibility = wgpu.ShaderStages.fragment,
                .buffer = .{
                    .@"type" = .uniform,
                    .has_dynamic_offset = @intFromBool(false),
                    .min_binding_size = @sizeOf(f32),
                },
            },
        };
        const bind_group_layout = swapchain.device.createBindGroupLayout(&wgpu.BindGroupLayoutDescriptor{
            .label = wgpu.StringView.fromSlice("gradient-bind-group-layout"),
            .entry_count = bind_group_layout_entries.len,
            .entries = &bind_group_layout_entries,
        }) orelse return error.BindGroupLayoutCreationFailed;
        defer bind_group_layout.release();

        // Create bind group
        var bind_group_entries = [_]wgpu.BindGroupEntry{
            .{
                .binding = 0,
                .buffer = time_buffer,
                .offset = 0,
                .size = @sizeOf(f32),
            },
        };
        const bind_group = swapchain.device.createBindGroup(&wgpu.BindGroupDescriptor{
            .label = wgpu.StringView.fromSlice("gradient-bind-group"),
            .layout = bind_group_layout,
            .entry_count = bind_group_entries.len,
            .entries = &bind_group_entries,
        }) orelse return error.BindGroupCreationFailed;
        errdefer bind_group.release();

        // Create pipeline layout
        var bind_group_layouts = [_]*const wgpu.BindGroupLayout{bind_group_layout};
        const pipeline_layout = swapchain.device.createPipelineLayout(&wgpu.PipelineLayoutDescriptor{
            .label = wgpu.StringView.fromSlice("gradient-pipeline-layout"),
            .bind_group_layout_count = bind_group_layouts.len,
            .bind_group_layouts = @ptrCast(&bind_group_layouts),
        }) orelse return error.PipelineLayoutCreationFailed;
        defer pipeline_layout.release();

        // Create render pipeline
        var color_targets = [_]wgpu.ColorTargetState{
            .{
                .format = swapchain.format,
                .blend = &wgpu.BlendState{
                    .color = .{ .src_factor = .one, .dst_factor = .zero, .operation = .add },
                    .alpha = .{ .src_factor = .one, .dst_factor = .zero, .operation = .add },
                },
                .write_mask = wgpu.ColorWriteMasks.all,
            },
        };
        const pipeline = swapchain.device.createRenderPipeline(&wgpu.RenderPipelineDescriptor{
            .label = wgpu.StringView.fromSlice("gradient-pipeline"),
            .layout = pipeline_layout,
            .vertex = .{
                .module = shader_module,
                .entry_point = wgpu.StringView.fromSlice("vs_main"),
            },
            .fragment = &wgpu.FragmentState{
                .module = shader_module,
                .entry_point = wgpu.StringView.fromSlice("fs_main"),
                .target_count = color_targets.len,
                .targets = &color_targets,
            },
            .primitive = .{
                .topology = .triangle_list,
                .strip_index_format = .undefined,
                .front_face = .ccw,
                .cull_mode = .none,
            },
            .multisample = .{
                .count = 1,
                .mask = 0xFFFFFFFF,
                .alpha_to_coverage_enabled = @intFromBool(false),
            },
        }) orelse return error.PipelineCreationFailed;

        return .{
            .swapchain = swapchain,
            .pipeline = pipeline,
            .bind_group = bind_group,
            .time_buffer = time_buffer,
            .start_time = std.time.nanoTimestamp(),
            .device_lost = device_lost,
        };
    }

    pub fn deinit(self: *SimpleSwapChain) void {
        self.pipeline.release();
        self.bind_group.release();
        self.time_buffer.release();
        self.swapchain.deinit();
    }

    pub fn resize(self: *SimpleSwapChain, width: u32, height: u32) void {
        self.swapchain.resize(width, height);
    }

    pub fn render(self: *SimpleSwapChain) bool {
        // Handle reconfigure if needed
        if (self.swapchain.needs_reconfigure) {
            self.swapchain.needs_reconfigure = false;
            self.swapchain.resize(self.swapchain.width, self.swapchain.height);
        }

        // Update time uniform
        const elapsed_ns = std.time.nanoTimestamp() - self.start_time;
        const time: f32 = @as(f32, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
        self.swapchain.queue.writeBuffer(self.time_buffer, 0, &time, @sizeOf(f32));

        // Acquire and render frame
        if (self.swapchain.acquireFrame()) |frame_value| {
            var frame = frame_value;
            defer frame.release();

            const encoder = self.swapchain.device.createCommandEncoder(&wgpu.CommandEncoderDescriptor{}) orelse return true;
            defer encoder.release();

            const color_attachment = wgpu.ColorAttachment{
                .view = frame.view,
                .load_op = wgpu.LoadOp.clear,
                .store_op = wgpu.StoreOp.store,
                .clear_value = wgpu.Color{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 1.0 },
            };
            var color_attachments = [_]wgpu.ColorAttachment{color_attachment};
            const pass = encoder.beginRenderPass(&wgpu.RenderPassDescriptor{
                .label = wgpu.StringView.fromSlice("gradient-pass"),
                .color_attachment_count = 1,
                .color_attachments = &color_attachments,
            }) orelse return true;

            pass.setPipeline(self.pipeline);
            pass.setBindGroup(0, self.bind_group, 0, null);
            pass.draw(3, 1, 0, 0);
            pass.end();
            pass.release();

            const command_buffer = encoder.finish(null) orelse return true;
            defer command_buffer.release();

            var command_buffers = [_]*const wgpu.CommandBuffer{command_buffer};
            self.swapchain.queue.submit(command_buffers[0..]);
            frame.present();
        } else |err| switch (err) {
            error.Timeout => {},
            error.Outdated, error.Lost => self.swapchain.resize(self.swapchain.width, self.swapchain.height),
            error.DeviceLost, error.OutOfMemory => return false,
            error.TextureError, error.TextureUnavailable => {},
        }

        return !self.device_lost;
    }
};
