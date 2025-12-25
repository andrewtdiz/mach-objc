const std = @import("std");
const testing = @import("testing");
const math = @import("math");

test "eql_vec2" {
    const a: math.Vec2 = math.vec2(92, 103);
    const b: math.Vec2 = math.vec2(92, 103);
    const c: math.Vec2 = math.vec2(92, 103.2);

    try testing.expect(bool, true).eql(a.eql(&b));
    try testing.expect(bool, false).eql(a.eql(&c));
}

test "eql_vec3" {
    const a: math.Vec3 = math.vec3(92, 103, 576);
    const b: math.Vec3 = math.vec3(92, 103, 576);
    const c: math.Vec3 = math.vec3(92.009, 103.2, 578);

    try testing.expect(bool, true).eql(a.eql(&b));
    try testing.expect(bool, false).eql(a.eql(&c));
}

test "eqlApprox_vec2" {
    const a: math.Vec2 = math.vec2(92.92837, 103.54682);
    const b: math.Vec2 = math.vec2(92.92998, 103.54791);

    try testing.expect(bool, true).eql(a.eqlApprox(&b, 1e-2));
    try testing.expect(bool, false).eql(a.eqlApprox(&b, 1e-3));
}

test "eqlApprox_vec3" {
    const a: math.Vec3 = math.vec3(92.92837, 103.54682, 256.9);
    const b: math.Vec3 = math.vec3(92.92998, 103.54791, 256.9);

    try testing.expect(bool, true).eql(a.eqlApprox(&b, 1e-2));
    try testing.expect(bool, false).eql(a.eqlApprox(&b, 1e-3));
}

test "gpu_compatibility" {
    // https://www.w3.org/TR/WGSL/#alignment-and-size
    try testing.expect(usize, 8).eql(@sizeOf(math.Vec2)); // WGSL AlignOf 8, SizeOf 8
    try testing.expect(usize, 16).eql(@sizeOf(math.Vec3)); // WGSL AlignOf 16, SizeOf 12
    try testing.expect(usize, 16).eql(@sizeOf(math.Vec4)); // WGSL AlignOf 16, SizeOf 16

    try testing.expect(usize, 4).eql(@sizeOf(math.Vec2h)); // WGSL AlignOf 4, SizeOf 4
    try testing.expect(usize, 8).eql(@sizeOf(math.Vec3h)); // WGSL AlignOf 8, SizeOf 6
    try testing.expect(usize, 8).eql(@sizeOf(math.Vec4h)); // WGSL AlignOf 8, SizeOf 8

    try testing.expect(usize, 8 * 2).eql(@sizeOf(math.Vec2d)); // speculative
    try testing.expect(usize, 16 * 2).eql(@sizeOf(math.Vec3d)); // speculative
    try testing.expect(usize, 16 * 2).eql(@sizeOf(math.Vec4d)); // speculative
}

test "zero_struct_overhead" {
    // Proof that using Vec4 is equal to @Vector(4, f32)
    try testing.expect(usize, @alignOf(@Vector(4, f32))).eql(@alignOf(math.Vec4));
    try testing.expect(usize, @sizeOf(@Vector(4, f32))).eql(@sizeOf(math.Vec4));
}

test "dimensions" {
    try testing.expect(usize, 3).eql(math.Vec3.n);
}

test "type" {
    try testing.expect(type, f16).eql(math.Vec3h.T);
}

test "init" {
    try testing.expect(math.Vec3h, math.vec3h(1, 2, 3)).eql(math.vec3h(1, 2, 3));
}

test "splat" {
    try testing.expect(math.Vec3h, math.vec3h(1337, 1337, 1337)).eql(math.Vec3h.splat(1337));
}

test "swizzle_singular" {
    try testing.expect(f32, 1).eql(math.vec3(1, 2, 3).x());
    try testing.expect(f32, 2).eql(math.vec3(1, 2, 3).y());
    try testing.expect(f32, 3).eql(math.vec3(1, 2, 3).z());
}

test "len2" {
    try testing.expect(f32, 2).eql(math.vec2(1, 1).len2());
    try testing.expect(f32, 29).eql(math.vec3(2, 3, -4).len2());
    try testing.expect(f32, 38.115).eqlApprox(math.vec4(1.5, 2.25, 3.33, 4.44).len2(), 0.0001);
    try testing.expect(f32, 0).eql(math.vec4(0, 0, 0, 0).len2());
}

test "len" {
    try testing.expect(f32, 5).eql(math.vec2(3, 4).len());
    try testing.expect(f32, 6).eql(math.vec3(4, 4, 2).len());
    try testing.expect(f32, 6.17373468817700328621).eql(math.vec4(1.5, 2.25, 3.33, 4.44).len());
    try testing.expect(f32, 0).eql(math.vec4(0, 0, 0, 0).len());
}

test "normalize_example" {
    const normalized = math.vec4(10, 0.5, -3, -0.2).normalize(math.eps_f32);
    try testing.expect(math.Vec4, math.vec4(0.95, 0.05, -0.3, -0.02)).eqlApprox(normalized, 0.1);
}

test "normalize_accuracy" {
    const normalized = math.vec2(1, 1).normalize(0);
    const norm_val = math.sqrt1_2; // 1 / sqrt(2)
    try testing.expect(math.Vec2, math.Vec2.splat(norm_val)).eql(normalized);
}

test "normalize_nan" {
    const near_zero = 0.0;
    const normalized = math.vec2(0, 0).normalize(near_zero);
    try testing.expect(bool, true).eql(math.isNan(normalized.x()));
}

test "normalize_no_nan" {
    const near_zero = math.eps_f32;
    const normalized = math.vec2(0, 0).normalize(near_zero);
    try testing.expect(math.Vec2, math.vec2(0, 0)).eqlBinary(normalized);
}

test "max_vec2" {
    const a: math.Vec2 = math.vec2(92, 0);
    const b: math.Vec2 = math.vec2(100, -1);
    try testing.expect(
        math.Vec2,
        math.vec2(100, 0),
    ).eql(math.Vec2.max(&a, &b));
}

test "max_vec3" {
    const a: math.Vec3 = math.vec3(92, 0, -2);
    const b: math.Vec3 = math.vec3(100, -1, -1);
    try testing.expect(
        math.Vec3,
        math.vec3(100, 0, -1),
    ).eql(math.Vec3.max(&a, &b));
}

test "max_vec4" {
    const a: math.Vec4 = math.vec4(92, 0, -2, 5);
    const b: math.Vec4 = math.vec4(100, -1, -1, 3);
    try testing.expect(
        math.Vec4,
        math.vec4(100, 0, -1, 5),
    ).eql(math.Vec4.max(&a, &b));
}

test "min_vec2" {
    const a: math.Vec2 = math.vec2(92, 0);
    const b: math.Vec2 = math.vec2(100, -1);
    try testing.expect(
        math.Vec2,
        math.vec2(92, -1),
    ).eql(math.Vec2.min(&a, &b));
}

test "min_vec3" {
    const a: math.Vec3 = math.vec3(92, 0, -2);
    const b: math.Vec3 = math.vec3(100, -1, -1);
    try testing.expect(
        math.Vec3,
        math.vec3(92, -1, -2),
    ).eql(math.Vec3.min(&a, &b));
}

test "min_vec4" {
    const a: math.Vec4 = math.vec4(92, 0, -2, 5);
    const b: math.Vec4 = math.vec4(100, -1, -1, 3);
    try testing.expect(
        math.Vec4,
        math.vec4(92, -1, -2, 3),
    ).eql(math.Vec4.min(&a, &b));
}

test "inverse_vec2" {
    const a: math.Vec2 = math.vec2(5, 4);
    try testing.expect(
        math.Vec2,
        math.vec2(0.2, 0.25),
    ).eql(math.Vec2.inverse(&a));
}

test "inverse_vec3" {
    const a: math.Vec3 = math.vec3(5, 4, -2);
    try testing.expect(
        math.Vec3,
        math.vec3(0.2, 0.25, -0.5),
    ).eql(math.Vec3.inverse(&a));
}

test "inverse_vec4" {
    const a: math.Vec4 = math.vec4(5, 4, -2, 3);
    try testing.expect(
        math.Vec4,
        math.vec4(0.2, 0.25, -0.5, 0.333333333),
    ).eql(math.Vec4.inverse(&a));
}

test "negate_vec2" {
    const a: math.Vec2 = math.vec2(9, 0.25);
    try testing.expect(
        math.Vec2,
        math.vec2(-9, -0.25),
    ).eql(math.Vec2.negate(&a));
}

test "negate_vec3" {
    const a: math.Vec3 = math.vec3(9, 0.25, 23.8);
    try testing.expect(
        math.Vec3,
        math.vec3(-9, -0.25, -23.8),
    ).eql(math.Vec3.negate(&a));
}

test "negate_vec4" {
    const a: math.Vec4 = math.vec4(9, 0.25, 23.8, -1.2);
    try testing.expect(
        math.Vec4,
        math.vec4(-9, -0.25, -23.8, 1.2),
    ).eql(math.Vec4.negate(&a));
}

test "maxScalar" {
    const a: math.Vec4 = math.vec4(0, 24, -20, 4);
    const b: math.Vec4 = math.vec4(5, -35, 72, 12);
    const c: math.Vec4 = math.vec4(16, 2, 93, -182);

    try testing.expect(f32, 72).eql(math.Vec4.maxScalar(&a, &b));
    try testing.expect(f32, 93).eql(math.Vec4.maxScalar(&b, &c));
}

test "minScalar" {
    const a: math.Vec4 = math.vec4(0, 24, -20, 4);
    const b: math.Vec4 = math.vec4(5, -35, 72, 12);
    const c: math.Vec4 = math.vec4(16, 2, 81, -182);

    try testing.expect(f32, -35).eql(math.Vec4.minScalar(&a, &b));
    try testing.expect(f32, -182).eql(math.Vec4.minScalar(&b, &c));
}

test "add_vec2" {
    const a: math.Vec2 = math.vec2(4, 1);
    const b: math.Vec2 = math.vec2(3, 4);
    try testing.expect(math.Vec2, math.vec2(7, 5)).eql(a.add(&b));
}

test "add_vec3" {
    const a: math.Vec3 = math.vec3(5, 12, 9.2);
    const b: math.Vec3 = math.vec3(7.5, 920, 11);
    try testing.expect(math.Vec3, math.vec3(12.5, 932, 20.2)).eql(a.add(&b));
}

test "add_vec4" {
    const a: math.Vec4 = math.vec4(1280, 910, 926.25, 1000);
    const b: math.Vec4 = math.vec4(20, 1090, 2.25, 2100);
    try testing.expect(math.Vec4, math.vec4(1300, 2000, 928.5, 3100))
        .eql(a.add(&b));
}

test "sub_vec2" {
    const a: math.Vec2 = math.vec2(19, 1);
    const b: math.Vec2 = math.vec2(3, 1);
    try testing.expect(math.Vec2, math.vec2(16, 0)).eql(a.sub(&b));
}

test "sub_vec3" {
    const a: math.Vec3 = math.vec3(7.5, 220, 13);
    const b: math.Vec3 = math.vec3(2, 9, 6);
    try testing.expect(math.Vec3, math.vec3(5.5, 211, 7)).eql(a.sub(&b));
}

test "sub_vec4" {
    const a: math.Vec4 = math.vec4(2023, 7, 2, 7);
    const b: math.Vec4 = math.vec4(-2, -2, -5, -3);
    try testing.expect(math.Vec4, math.vec4(2025, 9, 7, 10))
        .eql(a.sub(&b));
}

test "div_vec2" {
    const a: math.Vec2 = math.vec2(1, 2.8);
    const b: math.Vec2 = math.vec2(2, 4);
    try testing.expect(math.Vec2, math.vec2(0.5, 0.7)).eql(a.div(&b));
}

test "div_vec3" {
    const a: math.Vec3 = math.vec3(21, 144, 1);
    const b: math.Vec3 = math.vec3(3, 12, 3);
    try testing.expect(math.Vec3, math.vec3(7, 12, 0.3333333))
        .eql(a.div(&b));
}

test "div_vec4" {
    const a: math.Vec4 = math.vec4(1024, 512, 29, 3);
    const b: math.Vec4 = math.vec4(2, 2, 2, 10);
    try testing.expect(math.Vec4, math.vec4(512, 256, 14.5, 0.3))
        .eql(a.div(&b));
}

test "mul_vec2" {
    const a: math.Vec2 = math.vec2(29, 900);
    const b: math.Vec2 = math.vec2(29, 2.2);
    try testing.expect(math.Vec2, math.vec2(841, 1980)).eql(a.mul(&b));
}

test "mul_vec3" {
    const a: math.Vec3 = math.vec3(3.72, 9.217, 9);
    const b: math.Vec3 = math.vec3(2.1, 3.3, 9);
    try testing.expect(math.Vec3, math.vec3(7.812, 30.4161, 81))
        .eql(a.mul(&b));
}

test "mul_vec4" {
    const a: math.Vec4 = math.vec4(3.72, 9.217, 9, 21);
    const b: math.Vec4 = math.vec4(2.1, 3.3, 9, 15);
    try testing.expect(math.Vec4, math.vec4(7.812, 30.4161, 81, 315))
        .eql(a.mul(&b));
}

test "addScalar_vec2" {
    const a: math.Vec2 = math.vec2(92, 78);
    const s: f32 = 13;
    try testing.expect(math.Vec2, math.vec2(105, 91))
        .eql(a.addScalar(s));
}

test "addScalar_vec3" {
    const a: math.Vec3 = math.vec3(92, 78, 120);
    const s: f32 = 13;
    try testing.expect(math.Vec3, math.vec3(105, 91, 133))
        .eql(a.addScalar(s));
}

test "addScalar_vec4" {
    const a: math.Vec4 = math.vec4(92, 78, 120, 111);
    const s: f32 = 13;
    try testing.expect(math.Vec4, math.vec4(105, 91, 133, 124))
        .eql(a.addScalar(s));
}

test "subScalar_vec2" {
    const a: math.Vec2 = math.vec2(1000.1, 3);
    const s: f32 = 1;
    try testing.expect(math.Vec2, math.vec2(999.1, 2))
        .eql(a.subScalar(s));
}

test "subScalar_vec3" {
    const a: math.Vec3 = math.vec3(1000.1, 3, 5);
    const s: f32 = 1;
    try testing.expect(math.Vec3, math.vec3(999.1, 2, 4))
        .eql(a.subScalar(s));
}

test "subScalar_vec4" {
    const a: math.Vec4 = math.vec4(1000.1, 3, 5, 38);
    const s: f32 = 1;
    try testing.expect(math.Vec4, math.vec4(999.1, 2, 4, 37))
        .eql(a.subScalar(s));
}

test "divScalar_vec2" {
    const a: math.Vec2 = math.vec2(13, 15);
    const s: f32 = 2;
    try testing.expect(math.Vec2, math.vec2(6.5, 7.5))
        .eql(a.divScalar(s));
}

test "divScalar_vec3" {
    const a: math.Vec3 = math.vec3(13, 15, 12);
    const s: f32 = 2;
    try testing.expect(math.Vec3, math.vec3(6.5, 7.5, 6))
        .eql(a.divScalar(s));
}

test "divScalar_vec4" {
    const a: math.Vec4 = math.vec4(13, 15, 12, 29);
    const s: f32 = 2;
    try testing.expect(math.Vec4, math.vec4(6.5, 7.5, 6, 14.5))
        .eql(a.divScalar(s));
}

test "mulScalar_vec2" {
    const a: math.Vec2 = math.vec2(10, 125);
    const s: f32 = 5;
    try testing.expect(math.Vec2, math.vec2(50, 625))
        .eql(a.mulScalar(s));
}

test "mulScalar_vec3" {
    const a: math.Vec3 = math.vec3(10, 125, 3);
    const s: f32 = 5;
    try testing.expect(math.Vec3, math.vec3(50, 625, 15))
        .eql(a.mulScalar(s));
}

test "mulScalar_vec4" {
    const a: math.Vec4 = math.vec4(10, 125, 3, 27);
    const s: f32 = 5;
    try testing.expect(math.Vec4, math.vec4(50, 625, 15, 135))
        .eql(a.mulScalar(s));
}

test "dir_zero_vec2" {
    const near_zero_value = 1e-8;
    const a: math.Vec2 = math.vec2(0, 0);
    const b: math.Vec2 = math.vec2(0, 0);
    try testing.expect(math.Vec2, math.vec2(0, 0))
        .eql(a.dir(&b, near_zero_value));
}

test "dir_zero_vec3" {
    const near_zero_value = 1e-8;
    const a: math.Vec3 = math.vec3(0, 0, 0);
    const b: math.Vec3 = math.vec3(0, 0, 0);
    try testing.expect(math.Vec3, math.vec3(0, 0, 0))
        .eql(a.dir(&b, near_zero_value));
}

test "dir_zero_vec4" {
    const near_zero_value = 1e-8;
    const a: math.Vec4 = math.vec4(0, 0, 0, 0);
    const b: math.Vec4 = math.vec4(0, 0, 0, 0);
    try testing.expect(math.Vec4, math.vec4(0, 0, 0, 0))
        .eql(a.dir(&b, near_zero_value));
}

test "dir_vec2" {
    const a: math.Vec2 = math.vec2(1, 2);
    const b: math.Vec2 = math.vec2(3, 4);
    try testing.expect(math.Vec2, math.vec2(math.sqrt1_2, math.sqrt1_2))
        .eql(a.dir(&b, 0));
}

test "dir_vec3" {
    const a: math.Vec3 = math.vec3(1, -1, 0);
    const b: math.Vec3 = math.vec3(0, 1, 1);

    const result_x = -0.40824829046386301637; // -1 / sqrt(6)
    const result_y = 0.81649658092772603273; // sqrt(2/3)
    const result_z = -result_x; // 1 / sqrt(6)

    try testing.expect(math.Vec3, math.vec3(result_x, result_y, result_z))
        .eql(a.dir(&b, 0));
}

test "dist_zero_vec2" {
    const a: math.Vec2 = math.vec2(0, 0);
    const b: math.Vec2 = math.vec2(0, 0);
    try testing.expect(f32, 0).eql(a.dist(&b));
}

test "dist_zero_vec3" {
    const a: math.Vec3 = math.vec3(0, 0, 0);
    const b: math.Vec3 = math.vec3(0, 0, 0);
    try testing.expect(f32, 0).eql(a.dist(&b));
}

test "dist_zero_vec4" {
    const a: math.Vec4 = math.vec4(0, 0, 0, 0);
    const b: math.Vec4 = math.vec4(0, 0, 0, 0);
    try testing.expect(f32, 0).eql(a.dist(&b));
}

test "dist_vec2" {
    const a: math.Vec2 = math.vec2(1.5, 2.25);
    const b: math.Vec2 = math.vec2(1.44, -9.33);
    try testing.expect(f64, 11.5802)
        .eqlApprox(a.dist(&b), 1e-4);
}

test "dist_vec3" {
    const a: math.Vec3 = math.vec3(1.5, 2.25, 3.33);
    const b: math.Vec3 = math.vec3(1.44, -9.33, 7.25);
    try testing.expect(f64, 12.2256)
        .eqlApprox(a.dist(&b), 1e-4);
}

test "dist_vec4" {
    const a: math.Vec4 = math.vec4(1.5, 2.25, 3.33, 4.44);
    const b: math.Vec4 = math.vec4(1.44, -9.33, 7.25, -0.5);
    try testing.expect(f64, 13.186)
        .eqlApprox(a.dist(&b), 1e-4);
}

test "dist2_zero_vec2" {
    const a: math.Vec2 = math.vec2(0, 0);
    const b: math.Vec2 = math.vec2(0, 0);
    try testing.expect(f32, 0).eql(a.dist2(&b));
}

test "dist2_zero_vec3" {
    const a: math.Vec3 = math.vec3(0, 0, 0);
    const b: math.Vec3 = math.vec3(0, 0, 0);
    try testing.expect(f32, 0).eql(a.dist2(&b));
}

test "dist2_zero_vec4" {
    const a: math.Vec4 = math.vec4(0, 0, 0, 0);
    const b: math.Vec4 = math.vec4(0, 0, 0, 0);
    try testing.expect(f32, 0).eql(a.dist2(&b));
}

test "dist2_vec2" {
    const a: math.Vec2 = math.vec2(1.5, 2.25);
    const b: math.Vec2 = math.vec2(1.44, -9.33);
    try testing.expect(f64, 134.10103204).eqlApprox(a.dist2(&b), 1e-2);
}

test "dist2_vec3" {
    const a: math.Vec3 = math.vec3(1.5, 2.25, 3.33);
    const b: math.Vec3 = math.vec3(1.44, -9.33, 7.25);
    try testing.expect(f64, 149.46529536).eqlApprox(a.dist2(&b), 1e-2);
}

test "dist2_vec4" {
    const a: math.Vec4 = math.vec4(1.5, 2.25, 3.33, 4.44);
    const b: math.Vec4 = math.vec4(1.44, -9.33, 7.25, -0.5);
    try testing.expect(f64, 173.870596).eqlApprox(a.dist2(&b), 1e-3);
}

test "lerp_zero_vec2" {
    const a: math.Vec2 = math.vec2(1, 1);
    const b: math.Vec2 = math.vec2(0, 0);
    try testing.expect(math.Vec2, math.vec2(1, 1)).eql(a.lerp(&b, 0));
}

test "lerp_zero_vec3" {
    const a: math.Vec3 = math.vec3(1, 1, 1);
    const b: math.Vec3 = math.vec3(0, 0, 0);
    try testing.expect(math.Vec3, math.vec3(1, 1, 1)).eql(a.lerp(&b, 0));
}

test "lerp_zero_vec4" {
    const a: math.Vec4 = math.vec4(1, 1, 1, 1);
    const b: math.Vec4 = math.vec4(0, 0, 0, 0);
    try testing.expect(math.Vec4, math.vec4(1, 1, 1, 1)).eql(a.lerp(&b, 0));
}

test "cross" {
    const a: math.Vec3 = math.vec3(1, 3, 4);
    const b: math.Vec3 = math.vec3(2, -5, 8);
    try testing.expect(math.Vec3, math.vec3(44, 0, -11))
        .eql(a.cross(&b));

    const c: math.Vec3 = math.vec3(1.0, 0.0, 0.0);
    const d: math.Vec3 = math.vec3(0.0, 1.0, 0.0);
    try testing.expect(math.Vec3, math.vec3(0.0, 0.0, 1.0))
        .eql(c.cross(&d));

    const e: math.Vec3 = math.vec3(-3.0, 0.0, -2.0);
    const f: math.Vec3 = math.vec3(5.0, -1.0, 2.0);
    try testing.expect(math.Vec3, math.vec3(-2.0, -4.0, 3.0))
        .eql(e.cross(&f));
}

test "dot_vec2" {
    const a: math.Vec2 = math.vec2(-1, 2);
    const b: math.Vec2 = math.vec2(4, 5);
    try testing.expect(f32, 6).eql(a.dot(&b));
}

test "dot_vec3" {
    const a: math.Vec3 = math.vec3(-1, 2, 3);
    const b: math.Vec3 = math.vec3(4, 5, 6);
    try testing.expect(f32, 24).eql(a.dot(&b));
}

test "dot_vec4" {
    const a: math.Vec4 = math.vec4(-1, 2, 3, -2);
    const b: math.Vec4 = math.vec4(4, 5, 6, 2);
    try testing.expect(f32, 20).eql(a.dot(&b));
}

test "Mat3x3_mulMat" {
    const matrix = math.Mat3x3.init(
        &math.vec3(2, 2, 2),
        &math.vec3(3, 4, 3),
        &math.vec3(1, 1, 2),
    );
    const v = math.vec3(1, 2, 0);

    const m = math.Vec3.mulMat(&v, &matrix);
    const expected = math.vec3(8, 10, 8);
    try testing.expect(math.Vec3, expected).eql(m);
}

test "Mat4x4_mulMat" {
    const matrix = math.Mat4x4.init(
        &math.vec4(2, 2, 2, 1),
        &math.vec4(3, 4, 3, 0),
        &math.vec4(1, 1, 2, 2),
        &math.vec4(1, 1, 2, 2),
    );
    const v = math.vec4(1, 2, 0, -1);

    const m = math.Vec4.mulMat(&v, &matrix);
    const expected = math.vec4(7, 9, 6, -1);
    try testing.expect(math.Vec4, expected).eql(m);
}

test "mulQuat" {
    const up = math.vec3(0, 1, 0);
    const id = math.Quat.identity();
    const rot = math.Quat.rotateZ(&id, -math.pi / 2.0);
    try testing.expect(math.Vec3, math.vec3(1, 0, 0)).eql(up.mulQuat(&rot));
}

test "Vec2_fromInt" {
    const x: i8 = 0;
    const y: i32 = 1;
    const v = math.vec2FromInt(x, y);
    const expected = math.vec2(0, 1);
    try testing.expect(math.Vec2, expected).eql(v);
}

test "Vec3_fromInt" {
    const x: i8 = 0;
    const y: i32 = 1;
    const z: i64 = 2;
    const v = math.vec3FromInt(x, y, z);
    const expected = math.vec3(0, 1, 2);
    try testing.expect(math.Vec3, expected).eql(v);
}

test "Vec4_fromInt" {
    const x: i8 = 0;
    const y: i32 = 1;
    const z: i64 = 2;
    const w: i128 = 3;
    const v = math.vec4FromInt(x, y, z, w);
    const expected = math.vec4(0, 1, 2, 3);
    try testing.expect(math.Vec4, expected).eql(v);
}

test "Vec4d_fromInt" {
    const x: i8 = 0;
    const y: i32 = 1;
    const z: i64 = 2;
    const w: i128 = 3;
    const v = math.vec4dFromInt(x, y, z, w);
    const expected = math.vec4d(0, 1, 2, 3);
    try testing.expect(math.Vec4d, expected).eql(v);
}
