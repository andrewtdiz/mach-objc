const std = @import("std");
const testing = @import("testing");
const math = @import("math");

test "gpu_compatibility" {
    // https://www.w3.org/TR/WGSL/#alignment-and-size
    try testing.expect(usize, 16).eql(@sizeOf(math.Mat2x2));
    try testing.expect(usize, 48).eql(@sizeOf(math.Mat3x3));
    try testing.expect(usize, 64).eql(@sizeOf(math.Mat4x4));

    try testing.expect(usize, 8).eql(@sizeOf(math.Mat2x2h));
    try testing.expect(usize, 24).eql(@sizeOf(math.Mat3x3h));
    try testing.expect(usize, 32).eql(@sizeOf(math.Mat4x4h));

    try testing.expect(usize, 32).eql(@sizeOf(math.Mat2x2d)); // speculative
    try testing.expect(usize, 96).eql(@sizeOf(math.Mat3x3d)); // speculative
    try testing.expect(usize, 128).eql(@sizeOf(math.Mat4x4d)); // speculative
}

test "zero_struct_overhead" {
    // Proof that using e.g. [3]Vec3 is equal to [3]@Vector(3, f32)
    try testing.expect(usize, @alignOf([2]@Vector(2, f32))).eql(@alignOf(math.Mat2x2));
    try testing.expect(usize, @alignOf([3]@Vector(3, f32))).eql(@alignOf(math.Mat3x3));
    try testing.expect(usize, @alignOf([4]@Vector(4, f32))).eql(@alignOf(math.Mat4x4));
    try testing.expect(usize, @sizeOf([2]@Vector(2, f32))).eql(@sizeOf(math.Mat2x2));
    try testing.expect(usize, @sizeOf([3]@Vector(3, f32))).eql(@sizeOf(math.Mat3x3));
    try testing.expect(usize, @sizeOf([4]@Vector(4, f32))).eql(@sizeOf(math.Mat4x4));
}

test "n" {
    try testing.expect(usize, 3).eql(math.Mat3x3.cols);
    try testing.expect(usize, 3).eql(math.Mat3x3.rows);
    try testing.expect(type, math.Vec3).eql(math.Mat3x3.Vec);
    try testing.expect(usize, 3).eql(math.Mat3x3.Vec.n);
}

test "init" {
    try testing.expect(math.Mat3x3, math.mat3x3(
        &math.vec3(1, 0, 1337),
        &math.vec3(0, 1, 7331),
        &math.vec3(0, 0, 1),
    )).eql(math.Mat3x3{
        .v = [_]math.Vec3{
            math.Vec3.init(1, 0, 0),
            math.Vec3.init(0, 1, 0),
            math.Vec3.init(1337, 7331, 1),
        },
    });
}

test "Mat2x2_ident" {
    try testing.expect(math.Mat2x2, math.Mat2x2.ident).eql(math.Mat2x2{
        .v = [_]math.Vec2{
            math.Vec2.init(1, 0),
            math.Vec2.init(0, 1),
        },
    });
}

test "Mat3x3_ident" {
    try testing.expect(math.Mat3x3, math.Mat3x3.ident).eql(math.Mat3x3{
        .v = [_]math.Vec3{
            math.Vec3.init(1, 0, 0),
            math.Vec3.init(0, 1, 0),
            math.Vec3.init(0, 0, 1),
        },
    });
}

test "Mat4x4_ident" {
    try testing.expect(math.Mat4x4, math.Mat4x4.ident).eql(math.Mat4x4{
        .v = [_]math.Vec4{
            math.Vec4.init(1, 0, 0, 0),
            math.Vec4.init(0, 1, 0, 0),
            math.Vec4.init(0, 0, 1, 0),
            math.Vec4.init(0, 0, 0, 1),
        },
    });
}

test "Mat2x2_row" {
    const m = math.Mat2x2.init(
        &math.vec2(0, 1),
        &math.vec2(2, 3),
    );
    try testing.expect(math.Vec2, math.vec2(0, 1)).eql(m.row(0));
    try testing.expect(math.Vec2, math.vec2(2, 3)).eql(m.row(@TypeOf(m).rows - 1));
}

test "Mat2x2_col" {
    const m = math.Mat2x2.init(
        &math.vec2(0, 1),
        &math.vec2(2, 3),
    );
    try testing.expect(math.Vec2, math.vec2(0, 2)).eql(m.col(0));
    try testing.expect(math.Vec2, math.vec2(1, 3)).eql(m.col(@TypeOf(m).cols - 1));
}

test "Mat3x3_row" {
    const m = math.Mat3x3.init(
        &math.vec3(0, 1, 2),
        &math.vec3(3, 4, 5),
        &math.vec3(6, 7, 8),
    );
    try testing.expect(math.Vec3, math.vec3(0, 1, 2)).eql(m.row(0));
    try testing.expect(math.Vec3, math.vec3(3, 4, 5)).eql(m.row(1));
    try testing.expect(math.Vec3, math.vec3(6, 7, 8)).eql(m.row(@TypeOf(m).rows - 1));
}

test "Mat3x3_col" {
    const m = math.Mat3x3.init(
        &math.vec3(0, 1, 2),
        &math.vec3(3, 4, 5),
        &math.vec3(6, 7, 8),
    );
    try testing.expect(math.Vec3, math.vec3(0, 3, 6)).eql(m.col(0));
    try testing.expect(math.Vec3, math.vec3(1, 4, 7)).eql(m.col(1));
    try testing.expect(math.Vec3, math.vec3(2, 5, 8)).eql(m.col(@TypeOf(m).cols - 1));
}

test "Mat4x4_row" {
    const m = math.Mat4x4.init(
        &math.vec4(0, 1, 2, 3),
        &math.vec4(4, 5, 6, 7),
        &math.vec4(8, 9, 10, 11),
        &math.vec4(12, 13, 14, 15),
    );
    try testing.expect(math.Vec4, math.vec4(0, 1, 2, 3)).eql(m.row(0));
    try testing.expect(math.Vec4, math.vec4(4, 5, 6, 7)).eql(m.row(1));
    try testing.expect(math.Vec4, math.vec4(8, 9, 10, 11)).eql(m.row(2));
    try testing.expect(math.Vec4, math.vec4(12, 13, 14, 15)).eql(m.row(@TypeOf(m).rows - 1));
}

test "Mat4x4_col" {
    const m = math.Mat4x4.init(
        &math.vec4(0, 1, 2, 3),
        &math.vec4(4, 5, 6, 7),
        &math.vec4(8, 9, 10, 11),
        &math.vec4(12, 13, 14, 15),
    );
    try testing.expect(math.Vec4, math.vec4(0, 4, 8, 12)).eql(m.col(0));
    try testing.expect(math.Vec4, math.vec4(1, 5, 9, 13)).eql(m.col(1));
    try testing.expect(math.Vec4, math.vec4(2, 6, 10, 14)).eql(m.col(2));
    try testing.expect(math.Vec4, math.vec4(3, 7, 11, 15)).eql(m.col(@TypeOf(m).cols - 1));
}

test "Mat2x2_transpose" {
    const m = math.Mat2x2.init(
        &math.vec2(0, 1),
        &math.vec2(2, 3),
    );
    try testing.expect(math.Mat2x2, math.Mat2x2.init(
        &math.vec2(0, 2),
        &math.vec2(1, 3),
    )).eql(m.transpose());
}

test "Mat3x3_transpose" {
    const m = math.Mat3x3.init(
        &math.vec3(0, 1, 2),
        &math.vec3(3, 4, 5),
        &math.vec3(6, 7, 8),
    );
    try testing.expect(math.Mat3x3, math.Mat3x3.init(
        &math.vec3(0, 3, 6),
        &math.vec3(1, 4, 7),
        &math.vec3(2, 5, 8),
    )).eql(m.transpose());
}

test "Mat4x4_transpose" {
    const m = math.Mat4x4.init(
        &math.vec4(0, 1, 2, 3),
        &math.vec4(4, 5, 6, 7),
        &math.vec4(8, 9, 10, 11),
        &math.vec4(12, 13, 14, 15),
    );
    try testing.expect(math.Mat4x4, math.Mat4x4.init(
        &math.vec4(0, 4, 8, 12),
        &math.vec4(1, 5, 9, 13),
        &math.vec4(2, 6, 10, 14),
        &math.vec4(3, 7, 11, 15),
    )).eql(m.transpose());
}

test "Mat2x2_scaleScalar" {
    const m = math.Mat2x2.scaleScalar(2);
    try testing.expect(math.Mat2x2, math.Mat2x2.init(
        &math.vec2(2, 0),
        &math.vec2(0, 1),
    )).eql(m);
}

test "Mat3x3_scale" {
    const m = math.Mat3x3.scale(math.vec2(2, 3));
    try testing.expect(math.Mat3x3, math.Mat3x3.init(
        &math.vec3(2, 0, 0),
        &math.vec3(0, 3, 0),
        &math.vec3(0, 0, 1),
    )).eql(m);
}

test "Mat3x3_scaleScalar" {
    const m = math.Mat3x3.scaleScalar(2);
    try testing.expect(math.Mat3x3, math.Mat3x3.init(
        &math.vec3(2, 0, 0),
        &math.vec3(0, 2, 0),
        &math.vec3(0, 0, 1),
    )).eql(m);
}

test "Mat4x4_scale" {
    const m = math.Mat4x4.scale(math.vec3(2, 3, 4));
    try testing.expect(math.Mat4x4, math.Mat4x4.init(
        &math.vec4(2, 0, 0, 0),
        &math.vec4(0, 3, 0, 0),
        &math.vec4(0, 0, 4, 0),
        &math.vec4(0, 0, 0, 1),
    )).eql(m);
}

test "Mat4x4_scaleScalar" {
    const m = math.Mat4x4.scaleScalar(2);
    try testing.expect(math.Mat4x4, math.Mat4x4.init(
        &math.vec4(2, 0, 0, 0),
        &math.vec4(0, 2, 0, 0),
        &math.vec4(0, 0, 2, 0),
        &math.vec4(0, 0, 0, 1),
    )).eql(m);
}

test "Mat3x3_translate" {
    const m = math.Mat3x3.translate(math.vec2(2, 3));
    try testing.expect(math.Mat3x3, math.Mat3x3.init(
        &math.vec3(1, 0, 2),
        &math.vec3(0, 1, 3),
        &math.vec3(0, 0, 1),
    )).eql(m);
}

test "Mat4x4_translate" {
    const m = math.Mat4x4.translate(math.vec3(2, 3, 4));
    try testing.expect(math.Mat4x4, math.Mat4x4.init(
        &math.vec4(1, 0, 0, 2),
        &math.vec4(0, 1, 0, 3),
        &math.vec4(0, 0, 1, 4),
        &math.vec4(0, 0, 0, 1),
    )).eql(m);
}

test "Mat3x3_translateScalar" {
    const m = math.Mat3x3.translateScalar(2);
    try testing.expect(math.Mat3x3, math.Mat3x3.init(
        &math.vec3(1, 0, 2),
        &math.vec3(0, 1, 2),
        &math.vec3(0, 0, 1),
    )).eql(m);
}

test "Mat2x2_translateScalar" {
    const m = math.Mat2x2.translateScalar(2);
    try testing.expect(math.Mat2x2, math.Mat2x2.init(
        &math.vec2(1, 2),
        &math.vec2(0, 1),
    )).eql(m);
}

test "Mat4x4_translateScalar" {
    const m = math.Mat4x4.translateScalar(2);
    try testing.expect(math.Mat4x4, math.Mat4x4.init(
        &math.vec4(1, 0, 0, 2),
        &math.vec4(0, 1, 0, 2),
        &math.vec4(0, 0, 1, 2),
        &math.vec4(0, 0, 0, 1),
    )).eql(m);
}

test "Mat3x3_translation" {
    const m = math.Mat3x3.translate(math.vec2(2, 3));
    try testing.expect(math.Vec2, math.vec2(2, 3)).eql(m.translation());
}

test "Mat4x4_translation" {
    const m = math.Mat4x4.translate(math.vec3(2, 3, 4));
    try testing.expect(math.Vec3, math.vec3(2, 3, 4)).eql(m.translation());
}

test "Mat2x2_mulVec_vec2_ident" {
    const v = math.Vec2.splat(1);
    const ident = math.Mat2x2.ident;
    const expected = v;
    const m = math.Mat2x2.mulVec(&ident, &v);

    try testing.expect(math.Vec2, expected).eql(m);
}

test "Mat2x2_mulVec_vec2" {
    const v = math.Vec2.splat(1);
    const mat = math.Mat2x2.init(
        &math.vec2(2, 0),
        &math.vec2(0, 2),
    );

    const m = math.Mat2x2.mulVec(&mat, &v);
    const expected = math.vec2(2, 2);
    try testing.expect(math.Vec2, expected).eql(m);
}

test "Mat3x3_mulVec_vec3_ident" {
    const v = math.Vec3.splat(1);
    const ident = math.Mat3x3.ident;
    const expected = v;
    const m = math.Mat3x3.mulVec(&ident, &v);

    try testing.expect(math.Vec3, expected).eql(m);
}

test "Mat3x3_mulVec_vec3" {
    const v = math.Vec3.splat(1);
    const mat = math.Mat3x3.init(
        &math.vec3(2, 0, 0),
        &math.vec3(0, 2, 0),
        &math.vec3(0, 0, 3),
    );

    const m = math.Mat3x3.mulVec(&mat, &v);
    const expected = math.vec3(2, 2, 3);
    try testing.expect(math.Vec3, expected).eql(m);
}

test "Mat4x4_mulVec_vec4" {
    const v = math.vec4(2, 5, 1, 8);
    const mat = math.Mat4x4.init(
        &math.vec4(1, 0, 2, 0),
        &math.vec4(0, 3, 0, 4),
        &math.vec4(0, 0, 5, 0),
        &math.vec4(6, 0, 0, 7),
    );

    const m = math.Mat4x4.mulVec(&mat, &v);
    const expected = math.vec4(4, 47, 5, 68);
    try testing.expect(math.Vec4, expected).eql(m);
}

test "Mat2x2_mul" {
    const a = math.Mat2x2.init(
        &math.vec2(4, 2),
        &math.vec2(7, 9),
    );
    const b = math.Mat2x2.init(
        &math.vec2(5, -7),
        &math.vec2(6, -3),
    );
    const c = math.Mat2x2.mul(&a, &b);

    const expected = math.Mat2x2.init(
        &math.vec2(32, -34),
        &math.vec2(89, -76),
    );
    try testing.expect(math.Mat2x2, expected).eql(c);
}

test "Mat3x3_mul" {
    const a = math.Mat3x3.init(
        &math.vec3(4, 2, -3),
        &math.vec3(7, 9, -8),
        &math.vec3(-1, 8, -8),
    );
    const b = math.Mat3x3.init(
        &math.vec3(5, -7, -8),
        &math.vec3(6, -3, 2),
        &math.vec3(-3, -4, 4),
    );
    const c = math.Mat3x3.mul(&a, &b);

    const expected = math.Mat3x3.init(
        &math.vec3(41, -22, -40),
        &math.vec3(113, -44, -70),
        &math.vec3(67, 15, -8),
    );
    try testing.expect(math.Mat3x3, expected).eql(c);
}

test "Mat4x4_mul" {
    const a = math.Mat4x4.init(
        &math.vec4(10, -5, 6, -2),
        &math.vec4(0, -1, 0, 9),
        &math.vec4(-1, 6, -4, 8),
        &math.vec4(9, -8, -6, -10),
    );
    const b = math.Mat4x4.init(
        &math.vec4(7, -7, -3, -8),
        &math.vec4(1, -1, -7, -2),
        &math.vec4(-10, 2, 2, -2),
        &math.vec4(10, -7, 7, 1),
    );
    const c = math.Mat4x4.mul(&a, &b);

    const expected = math.Mat4x4.init(
        &math.vec4(-15, -39, 3, -84),
        &math.vec4(89, -62, 70, 11),
        &math.vec4(119, -63, 9, 12),
        &math.vec4(15, 3, -53, -54),
    );
    try testing.expect(math.Mat4x4, expected).eql(c);
}

test "Mat4x4_eql_not_ident" {
    const m1 = math.Mat4x4.init(
        &math.vec4(0, 1, 2, 3),
        &math.vec4(4, 5, 6, 7),
        &math.vec4(8, 9, 10, 11),
        &math.vec4(12, 13, 14, 15),
    );
    const m2 = math.Mat4x4.init(
        &math.vec4(0, 1, 2, 3),
        &math.vec4(4.5, 5, 6, 7),
        &math.vec4(8, 9, 10, 11),
        &math.vec4(12, 13, 14, 15),
    );
    try testing.expect(bool, math.Mat4x4.eql(&m1, &m2)).eql(false);
}

test "Mat4x4_eql_ident" {
    const m1 = math.Mat4x4.init(
        &math.vec4(0, 1, 2, 3),
        &math.vec4(4, 5, 6, 7),
        &math.vec4(8, 9, 10, 11),
        &math.vec4(12, 13, 14, 15),
    );
    const m2 = math.Mat4x4.init(
        &math.vec4(0, 1, 2, 3),
        &math.vec4(4, 5, 6, 7),
        &math.vec4(8, 9, 10, 11),
        &math.vec4(12, 13, 14, 15),
    );
    try testing.expect(bool, math.Mat4x4.eql(&m1, &m2)).eql(true);
}

test "Mat4x4_eqlApprox_not_ident" {
    const m1 = math.Mat4x4.init(
        &math.vec4(0, 1, 2, 3),
        &math.vec4(4, 5, 6, 7),
        &math.vec4(8, 9, 10, 11),
        &math.vec4(12, 13, 14, 15),
    );
    const m2 = math.Mat4x4.init(
        &math.vec4(0, 1, 2, 3),
        &math.vec4(4.11, 5, 6, 7),
        &math.vec4(8, 9, 10, 11),
        &math.vec4(12, 13, 14, 15),
    );
    try testing.expect(bool, math.Mat4x4.eqlApprox(&m1, &m2, 0.1)).eql(false);
}

test "Mat4x4_eqlApprox_ident" {
    const m1 = math.Mat4x4.init(
        &math.vec4(0, 1, 2, 3),
        &math.vec4(4, 5, 6, 7),
        &math.vec4(8, 9, 10, 11),
        &math.vec4(12, 13, 14, 15),
    );
    const m2 = math.Mat4x4.init(
        &math.vec4(0, 1, 2, 3),
        &math.vec4(4.09, 5, 6, 7),
        &math.vec4(8, 9, 10, 11),
        &math.vec4(12, 13, 14, 15),
    );
    try testing.expect(bool, math.Mat4x4.eqlApprox(&m1, &m2, 0.1)).eql(true);
}

test "projection2D_xy_centered" {
    const left = -400;
    const right = 400;
    const bottom = -200;
    const top = 200;
    const near = 0;
    const far = 100;
    const m = math.Mat4x4.projection2D(.{
        .left = left,
        .right = right,
        .bottom = bottom,
        .top = top,
        .near = near,
        .far = far,
    });

    // Calculate some reference points
    const width = right - left;
    const height = top - bottom;
    const width_mid = left + (width / 2.0);
    const height_mid = bottom + (height / 2.0);
    try testing.expect(f32, 800).eql(width);
    try testing.expect(f32, 400).eql(height);
    try testing.expect(f32, 0).eql(width_mid);
    try testing.expect(f32, 0).eql(height_mid);

    // Probe some points on the X axis from beyond the left face, all the way to beyond the right face.
    try testing.expect(math.Vec4, math.vec4(-2, 0, 1, 1)).eql(m.mulVec(&math.vec4(left - (width / 2), height_mid, 0, 1)));
    try testing.expect(math.Vec4, math.vec4(-1, 0, 1, 1)).eql(m.mulVec(&math.vec4(left, height_mid, 0, 1)));
    try testing.expect(math.Vec4, math.vec4(-0.5, 0, 1, 1)).eql(m.mulVec(&math.vec4(left + (width / 4.0), height_mid, 0, 1)));
    try testing.expect(math.Vec4, math.vec4(0, 0, 1, 1)).eql(m.mulVec(&math.vec4(width_mid, height_mid, 0, 1)));
    try testing.expect(math.Vec4, math.vec4(0.5, 0, 1, 1)).eql(m.mulVec(&math.vec4(right - (width / 4.0), height_mid, 0, 1)));
    try testing.expect(math.Vec4, math.vec4(1, 0, 1, 1)).eql(m.mulVec(&math.vec4(right, height_mid, 0, 1)));
    try testing.expect(math.Vec4, math.vec4(2, 0, 1, 1)).eql(m.mulVec(&math.vec4(right + (width / 2), height_mid, 0, 1)));

    // Probe some points on the Y axis from beyond the bottom face, all the way to beyond the top face.
    try testing.expect(math.Vec4, math.vec4(0, -2, 1, 1)).eql(m.mulVec(&math.vec4(width_mid, bottom - (height / 2), 0, 1)));
    try testing.expect(math.Vec4, math.vec4(0, -1, 1, 1)).eql(m.mulVec(&math.vec4(width_mid, bottom, 0, 1)));
    try testing.expect(math.Vec4, math.vec4(0, -0.5, 1, 1)).eql(m.mulVec(&math.vec4(width_mid, bottom + (height / 4.0), 0, 1)));
    try testing.expect(math.Vec4, math.vec4(0, 0, 1, 1)).eql(m.mulVec(&math.vec4(width_mid, height_mid, 0, 1)));
    try testing.expect(math.Vec4, math.vec4(0, 0.5, 1, 1)).eql(m.mulVec(&math.vec4(width_mid, top - (height / 4.0), 0, 1)));
    try testing.expect(math.Vec4, math.vec4(0, 1, 1, 1)).eql(m.mulVec(&math.vec4(width_mid, top, 0, 1)));
    try testing.expect(math.Vec4, math.vec4(0, 2, 1, 1)).eql(m.mulVec(&math.vec4(width_mid, top + (height / 2), 0, 1)));
}

test "projection2D_xy_offcenter" {
    const left = 100;
    const right = 500;
    const bottom = 100;
    const top = 500;
    const near = 0;
    const far = 100;
    const m = math.Mat4x4.projection2D(.{
        .left = left,
        .right = right,
        .bottom = bottom,
        .top = top,
        .near = near,
        .far = far,
    });

    // Calculate some reference points
    const width = right - left;
    const height = top - bottom;
    const width_mid = left + (width / 2.0);
    const height_mid = bottom + (height / 2.0);
    try testing.expect(f32, 400).eql(width);
    try testing.expect(f32, 400).eql(height);
    try testing.expect(f32, 300).eql(width_mid);
    try testing.expect(f32, 300).eql(height_mid);

    // Probe some points on the X axis from beyond the left face, all the way to beyond the right face.
    try testing.expect(math.Vec4, math.vec4(-2, 0, 1, 1)).eql(m.mulVec(&math.vec4(left - (width / 2), height_mid, 0, 1)));
    try testing.expect(math.Vec4, math.vec4(-1, 0, 1, 1)).eql(m.mulVec(&math.vec4(left, height_mid, 0, 1)));
    try testing.expect(math.Vec4, math.vec4(-0.5, 0, 1, 1)).eql(m.mulVec(&math.vec4(left + (width / 4.0), height_mid, 0, 1)));
    try testing.expect(math.Vec4, math.vec4(0, 0, 1, 1)).eql(m.mulVec(&math.vec4(width_mid, height_mid, 0, 1)));
    try testing.expect(math.Vec4, math.vec4(0.5, 0, 1, 1)).eql(m.mulVec(&math.vec4(right - (width / 4.0), height_mid, 0, 1)));
    try testing.expect(math.Vec4, math.vec4(1, 0, 1, 1)).eql(m.mulVec(&math.vec4(right, height_mid, 0, 1)));
    try testing.expect(math.Vec4, math.vec4(2, 0, 1, 1)).eql(m.mulVec(&math.vec4(right + (width / 2), height_mid, 0, 1)));

    // Probe some points on the Y axis from beyond the bottom face, all the way to beyond the top face.
    try testing.expect(math.Vec4, math.vec4(0, -2, 1, 1)).eql(m.mulVec(&math.vec4(width_mid, bottom - (height / 2), 0, 1)));
    try testing.expect(math.Vec4, math.vec4(0, -1, 1, 1)).eql(m.mulVec(&math.vec4(width_mid, bottom, 0, 1)));
    try testing.expect(math.Vec4, math.vec4(0, -0.5, 1, 1)).eql(m.mulVec(&math.vec4(width_mid, bottom + (height / 4.0), 0, 1)));
    try testing.expect(math.Vec4, math.vec4(0, 0, 1, 1)).eql(m.mulVec(&math.vec4(width_mid, height_mid, 0, 1)));
    try testing.expect(math.Vec4, math.vec4(0, 0.5, 1, 1)).eql(m.mulVec(&math.vec4(width_mid, top - (height / 4.0), 0, 1)));
    try testing.expect(math.Vec4, math.vec4(0, 1, 1, 1)).eql(m.mulVec(&math.vec4(width_mid, top, 0, 1)));
    try testing.expect(math.Vec4, math.vec4(0, 2, 1, 1)).eql(m.mulVec(&math.vec4(width_mid, top + (height / 2), 0, 1)));
}

test "projection2D_z" {
    const m = math.Mat4x4.projection2D(.{
        // Set x=0 and y=0 as centers, so we can specify 0 centers in our testing.expects below
        .left = -400,
        .right = 400,
        .bottom = -200,
        .top = 200,

        // Choose some near/far plane values that we can easily test against
        // We'll have [near, far] == [-100, 100] == [1, 0]
        .near = -100,
        .far = 100,
    });

    // Probe some points on the Z axis from the near plane, all the way to the far plane.
    try testing.expect(math.Vec4, math.vec4(0, 0, 1, 1)).eql(m.mulVec(&math.vec4(0, 0, -100, 1)));
    try testing.expect(math.Vec4, math.vec4(0, 0, 0.75, 1)).eql(m.mulVec(&math.vec4(0, 0, -50, 1)));
    try testing.expect(math.Vec4, math.vec4(0, 0, 0.5, 1)).eql(m.mulVec(&math.vec4(0, 0, 0, 1)));
    try testing.expect(math.Vec4, math.vec4(0, 0, 0.25, 1)).eql(m.mulVec(&math.vec4(0, 0, 50, 1)));
    try testing.expect(math.Vec4, math.vec4(0, 0, 0, 1)).eql(m.mulVec(&math.vec4(0, 0, 100, 1)));

    // Probe some points outside the near/far planes
    try testing.expect(math.Vec4, math.vec4(0, 0, 2, 1)).eql(m.mulVec(&math.vec4(0, 0, -100 - 200, 1)));
    try testing.expect(math.Vec4, math.vec4(0, 0, -1, 1)).eql(m.mulVec(&math.vec4(0, 0, 100 + 200, 1)));
}

test "projection2D_z_positive" {
    const m = math.Mat4x4.projection2D(.{
        // Set x=0 and y=0 as centers, so we can specify 0 centers in our testing.expects below
        .left = -400,
        .right = 400,
        .bottom = -200,
        .top = 200,

        // Choose some near/far plane values that we can easily test against
        // We'll have [near, far] == [0, 100] == [1, 0]
        .near = 0,
        .far = 100,
    });

    // Probe some points on the Z axis from the near plane, all the way to the far plane.
    try testing.expect(math.Vec4, math.vec4(0, 0, 1, 1)).eql(m.mulVec(&math.vec4(0, 0, 0, 1)));
    try testing.expect(math.Vec4, math.vec4(0, 0, 0.75, 1)).eql(m.mulVec(&math.vec4(0, 0, 25, 1)));
    try testing.expect(math.Vec4, math.vec4(0, 0, 0.5, 1)).eql(m.mulVec(&math.vec4(0, 0, 50, 1)));
    try testing.expect(math.Vec4, math.vec4(0, 0, 0.25, 1)).eql(m.mulVec(&math.vec4(0, 0, 75, 1)));
    try testing.expect(math.Vec4, math.vec4(0, 0, 0, 1)).eql(m.mulVec(&math.vec4(0, 0, 100, 1)));

    // Probe some points outside the near/far planes
    try testing.expect(math.Vec4, math.vec4(0, 0, 2, 1)).eql(m.mulVec(&math.vec4(0, 0, 0 - 100, 1)));
    try testing.expect(math.Vec4, math.vec4(0, 0, -1, 1)).eql(m.mulVec(&math.vec4(0, 0, 100 + 100, 1)));
}

test "projection2D_model_to_clip_space" {
    const model = math.Mat4x4.ident;
    const view = math.Mat4x4.ident;
    const proj = math.Mat4x4.projection2D(.{
        .left = -50,
        .right = 50,
        .bottom = -50,
        .top = 50,
        .near = 0,
        .far = 100,
    });
    const mvp = model.mul(&view).mul(&proj);

    try testing.expect(math.Vec4, math.vec4(0, 0, 1.0, 1)).eql(mvp.mulVec(&math.vec4(0, 0, 0, 1)));
    try testing.expect(math.Vec4, math.vec4(0, 0, 0.5, 1)).eql(mvp.mulVec(&math.vec4(0, 0, 50, 1)));
    try testing.expect(math.Vec4, math.vec4(0, -1, 1, 1)).eql(mvp.mul(&math.Mat4x4.rotateX(math.degreesToRadians(90))).mulVec(&math.vec4(0, 0, 50, 1)));
    try testing.expect(math.Vec4, math.vec4(1, 0, 1, 1)).eql(mvp.mul(&math.Mat4x4.rotateY(math.degreesToRadians(90))).mulVec(&math.vec4(0, 0, 50, 1)));
    try testing.expect(math.Vec4, math.vec4(0, 0, 0.5, 1)).eql(mvp.mul(&math.Mat4x4.rotateZ(math.degreesToRadians(90))).mulVec(&math.vec4(0, 0, 50, 1)));
}

test "quaternion_rotation" {
    const expected = math.Mat4x4.init(
        &math.vec4(0.7716905, 0.5519065, 0.3160585, 0),
        &math.vec4(-0.0782971, -0.4107276, 0.9083900, 0),
        &math.vec4(0.6311602, -0.7257425, -0.2737419, 0),
        &math.vec4(0, 0, 0, 1),
    );

    const q = math.Quat.fromAxisAngle(math.vec3(0.9182788, 0.1770672, 0.3541344), 4.2384558);
    const result = math.Mat4x4.rotateByQuaternion(q.normalize());

    try testing.expect(bool, true).eql(expected.eqlApprox(&result, 0.0000002));
}
