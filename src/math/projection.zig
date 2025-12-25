//! Projection matrices for WebGPU rendering.
//!
//! WebGPU uses a different clip space than OpenGL:
//! - Depth range: [0, 1] (not [-1, 1])
//! - NDC Y: +1 at top, -1 at bottom (same as OpenGL)
//! - Clip space: left-handed (positive Z goes into screen)
//!
//! These functions return matrices compatible with the mach math library
//! (column-major storage, column-vectors for multiplication).

const std = @import("std");

const math = @import("main.zig");

/// Orthographic projection for 2D rendering with WebGPU depth range [0, 1].
///
/// Maps world coordinates to clip space:
/// - X: [left, right] → [-1, +1]
/// - Y: [bottom, top] → [-1, +1]
/// - Z: [near, far] → [0, 1]
///
/// Use this for 2D games, UI, and particle systems.
pub fn ortho2D(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) math.Mat4x4 {
    const rl = right - left;
    const tb = top - bottom;
    const fn_dist = far - near;

    // mat4x4.init takes ROWS and transposes to column-major for WGSL.
    // WebGPU depth: Z_clip = (Z_world - near) / (far - near) → [0, 1]
    return math.mat4x4(
        &math.vec4(2.0 / rl, 0.0, 0.0, -(right + left) / rl),
        &math.vec4(0.0, 2.0 / tb, 0.0, -(top + bottom) / tb),
        &math.vec4(0.0, 0.0, -1.0 / fn_dist, -near / fn_dist),
        &math.vec4(0.0, 0.0, 0.0, 1.0),
    );
}

/// Centered orthographic projection for 2D rendering.
///
/// Creates a symmetric view frustum centered at origin.
/// Useful for VFX systems that render in world-space coordinates.
///
/// Parameters:
/// - half_width: Half the view width (left = -half_width, right = +half_width)
/// - half_height: Half the view height (bottom = -half_height, top = +half_height)
/// - near: Near plane distance
/// - far: Far plane distance
pub fn ortho2DCentered(half_width: f32, half_height: f32, near: f32, far: f32) math.Mat4x4 {
    return ortho2D(-half_width, half_width, -half_height, half_height, near, far);
}

/// Screen-space orthographic projection for 2D rendering.
///
/// Maps screen pixel coordinates to clip space:
/// - X: [0, width] → [-1, +1]
/// - Y: [0, height] → [+1, -1] (Y-down screen coords to Y-up NDC)
/// - Z: [0, 1] → [0, 1]
///
/// Use this for UI, HUD, and 2D game sprites with screen-space positioning.
pub fn ortho2DScreen(width: f32, height: f32) math.Mat4x4 {
    // Screen coords: (0,0) = top-left, Y increases downward
    // NDC: (0,0) = center, Y increases upward
    // So we flip Y by using top=0, bottom=height
    return ortho2D(0.0, width, height, 0.0, 0.0, 1.0);
}

/// Perspective projection for 3D rendering with WebGPU depth range [0, 1].
///
/// Parameters:
/// - fov_y: Vertical field of view in radians
/// - aspect: Aspect ratio (width / height)
/// - near: Near plane distance (must be > 0)
/// - far: Far plane distance (must be > near)
///
/// Uses infinite far plane when far <= 0 or far == infinity.
pub fn perspective(fov_y: f32, aspect: f32, near: f32, far: f32) math.Mat4x4 {
    const tan_half_fov = @tan(fov_y * 0.5);
    const f = 1.0 / tan_half_fov;

    if (far <= 0 or std.math.isInf(far)) {
        // Infinite far plane (reversed-Z for better precision)
        return math.mat4x4(
            &math.vec4(f / aspect, 0.0, 0.0, 0.0),
            &math.vec4(0.0, f, 0.0, 0.0),
            &math.vec4(0.0, 0.0, 0.0, near),
            &math.vec4(0.0, 0.0, -1.0, 0.0),
        );
    }

    const fn_dist = far - near;
    // WebGPU: Z_clip in [0, 1]
    return math.mat4x4(
        &math.vec4(f / aspect, 0.0, 0.0, 0.0),
        &math.vec4(0.0, f, 0.0, 0.0),
        &math.vec4(0.0, 0.0, -far / fn_dist, -(far * near) / fn_dist),
        &math.vec4(0.0, 0.0, -1.0, 0.0),
    );
}

/// Calculate view frustum dimensions at a given distance from camera.
///
/// Useful for converting between screen space and world space for VFX.
///
/// Parameters:
/// - fov_y: Vertical field of view in radians
/// - aspect: Aspect ratio (width / height)
/// - distance: Distance from camera to the plane
///
/// Returns: .{ half_width, half_height } at the given distance
pub fn frustumHalfExtentsAt(fov_y: f32, aspect: f32, distance: f32) struct { half_width: f32, half_height: f32 } {
    const half_height = distance * @tan(fov_y * 0.5);
    const half_width = half_height * aspect;
    return .{ .half_width = half_width, .half_height = half_height };
}
