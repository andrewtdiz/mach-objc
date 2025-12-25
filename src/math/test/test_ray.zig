const std = @import("std");
const testing = @import("testing");
const math = @import("math");

test "triangleIntersect_basic_frontface_bc_hit" {
    const a: math.Vec3 = math.vec3(0, 0, 0);
    const b: math.Vec3 = math.vec3(1, 0, 0);
    const c: math.Vec3 = math.vec3(0, 1, 0);
    const ray0: math.Ray = math.Ray{
        .origin = math.vec3(0.1, 0.1, 1),
        .direction = math.vec3(0.1, 0.1, -1),
    };

    const result: math.Ray.Hit = ray0.triangleIntersect(
        &a,
        &b,
        &c,
        true,
    ).?;

    const expected_t: f32 = 1;
    const expected_u: f32 = 0.6;
    const expected_v: f32 = 0.2;
    const expected_w: f32 = 0.2;
    try testing.expect(f32, expected_u).eql(result.v[0]);
    try testing.expect(f32, expected_v).eql(result.v[1]);
    try testing.expect(f32, expected_w).eql(result.v[2]);
    try testing.expect(f32, expected_t).eql(result.v[3]);
}

test "triangleIntersect_basic_backface_no_bc_hit" {
    const a: math.Vec3 = math.vec3(0, 0, 0);
    const b: math.Vec3 = math.vec3(1, 0, 0);
    const c: math.Vec3 = math.vec3(0, 1, 0);
    const ray0: math.Ray = math.Ray{
        .origin = math.vec3(0.1, 0.1, 1),
        .direction = math.vec3(0.1, 0.1, -1),
    };

    // Reverse winding from previous test
    const result: math.Ray.Hit = ray0.triangleIntersect(
        &a,
        &c,
        &b,
        false,
    ).?;

    const expected_t: f32 = 1;
    const expected_u: f32 = -0.6;
    const expected_v: f32 = -0.2;
    const expected_w: f32 = -0.2;
    try testing.expect(f32, expected_u).eql(result.v[0]);
    try testing.expect(f32, expected_v).eql(result.v[1]);
    try testing.expect(f32, expected_w).eql(result.v[2]);
    try testing.expect(f32, expected_t).eql(result.v[3]);
}

test "triangleIntersect_basic_backface_bc_miss" {
    const a: math.Vec3 = math.vec3(0, 0, 0);
    const b: math.Vec3 = math.vec3(1, 0, 0);
    const c: math.Vec3 = math.vec3(0, 1, 0);
    const ray0: math.Ray = math.Ray{
        .origin = math.vec3(0.1, 0.1, 1),
        .direction = math.vec3(0.1, 0.1, -1),
    };

    // Reverse winding from previous test
    const result: ?math.Ray.Hit = ray0.triangleIntersect(
        &a,
        &c,
        &b,
        true,
    );

    try testing.expect(?math.Ray.Hit, null).eql(result);
}

test "triangleIntersect_precise_frontface_bc_hit_f32" {
    const a: math.Vec3 = math.vec3(
        3164.91,
        3559.55,
        3044.54,
    );
    const b: math.Vec3 = math.vec3(
        1011.92,
        3113.34,
        3674.56,
    );
    const c: math.Vec3 = math.vec3(
        503.804,
        2311.16,
        2449.58,
    );
    const ray0: math.Ray = math.Ray{
        .origin = math.vec3(
            293.293,
            264.527,
            225.465,
        ),
        .direction = math.vec3(
            0.439063,
            0.652555,
            0.617573,
        ),
    };

    const result: math.Ray.Hit = ray0.triangleIntersect(
        &a,
        &b,
        &c,
        true,
    ).?;

    const expected_t: f32 = 4606.98;
    const expected_u: f32 = 0.643925;
    const expected_v: f32 = 0.194228;
    const expected_w: f32 = 0.161846;
    try testing.expect(f32, expected_u).eqlApprox(result.v[0], 1e-5);
    try testing.expect(f32, expected_v).eqlApprox(result.v[1], 1e-5);
    try testing.expect(f32, expected_w).eqlApprox(result.v[2], 1e-5);
    try testing.expect(f32, expected_t).eqlApprox(result.v[3], 1e-2);
}

test "triangleIntersect_precise_frontface_bc_hit_f64" {
    const a: math.Vec3d = math.vec3d(
        2371.01,
        3208.12,
        1570.04,
    );
    const b: math.Vec3d = math.vec3d(
        1412.2,
        2978.36,
        1501.33,
    );
    const c: math.Vec3d = math.vec3d(
        2520.99,
        3323.93,
        1567.18,
    );
    const ray0: math.Rayd = math.Rayd{
        .origin = math.vec3d(
            246.713,
            279.646,
            180.443,
        ),
        .direction = math.vec3d(
            0.497991,
            0.782698,
            0.373349,
        ),
    };

    const result: math.Rayd.Hit = ray0.triangleIntersect(
        &a,
        &b,
        &c,
        true,
    ).?;

    const expected_t: f64 = 3660.17;
    const expected_u: f64 = 0.56102;
    const expected_v: f64 = 0.33136;
    const expected_w: f64 = 0.10761;
    try testing.expect(f64, expected_u).eqlApprox(result.v[0], 1e-4);
    try testing.expect(f64, expected_v).eqlApprox(result.v[1], 1e-4);
    try testing.expect(f64, expected_w).eqlApprox(result.v[2], 1e-4);
    try testing.expect(f64, expected_t).eqlApprox(result.v[3], 1e-2);
}

test "triangleIntersect_ray_no_direction" {
    const a: math.Vec3 = math.vec3(0, 0, 0);
    const b: math.Vec3 = math.vec3(1, 0, 0);
    const c: math.Vec3 = math.vec3(0, 1, 0);
    const ray: math.Ray = math.Ray{
        .origin = math.vec3(0.1, 0.1, 1),
        .direction = math.vec3(0.0, 0.0, 0.0),
    };

    const result = ray.triangleIntersect(
        &a,
        &b,
        &c,
        true,
    );

    try testing.expect(?math.Ray.Hit, null).eql(result);
}

test "triangleIntersect_ray_no_x_y_direction" {
    const a: math.Vec3 = math.vec3(-1, 1, 0);
    const b: math.Vec3 = math.vec3(-1, -1, 0);
    const c: math.Vec3 = math.vec3(1, -1, 0);
    const ray: math.Ray = math.Ray{
        .origin = math.vec3(0.0, 0.0, 1),
        .direction = math.vec3(0.0, 0.0, -1),
    };

    const result = ray.triangleIntersect(
        &a,
        &b,
        &c,
        true,
    ).?;

    const expected_t: f64 = 1;
    const expected_u: f64 = 0.3333;
    const expected_v: f64 = 0.3333;
    const expected_w: f64 = 0.3333;
    try testing.expect(f64, expected_u).eqlApprox(result.v[0], 1e-4);
    try testing.expect(f64, expected_v).eqlApprox(result.v[1], 1e-4);
    try testing.expect(f64, expected_w).eqlApprox(result.v[2], 1e-4);
    try testing.expect(f64, expected_t).eqlApprox(result.v[3], 1e-2);
}

test "triangleIntersect_ray_no_y_z_direction" {
    const a: math.Vec3 = math.vec3(0, -1, 1);
    const b: math.Vec3 = math.vec3(0, -1, -1);
    const c: math.Vec3 = math.vec3(0, 1, -1);
    const ray: math.Ray = math.Ray{
        .origin = math.vec3(1, 0.0, 0.0),
        .direction = math.vec3(-1, 0.0, 0.0),
    };

    const result = ray.triangleIntersect(
        &a,
        &b,
        &c,
        true,
    ).?;
    const expected_t: f64 = 1;
    const expected_u: f64 = 0.3333;
    const expected_v: f64 = 0.3333;
    const expected_w: f64 = 0.3333;
    try testing.expect(f64, expected_u).eqlApprox(result.v[0], 1e-4);
    try testing.expect(f64, expected_v).eqlApprox(result.v[1], 1e-4);
    try testing.expect(f64, expected_w).eqlApprox(result.v[2], 1e-4);
    try testing.expect(f64, expected_t).eqlApprox(result.v[3], 1e-2);
}

test "triangleIntersect_ray_no_x_z_direction" {
    const a: math.Vec3 = math.vec3(-1, 0, 1);
    const b: math.Vec3 = math.vec3(-1, 0, -1);
    const c: math.Vec3 = math.vec3(1, 0, -1);
    const ray: math.Ray = math.Ray{
        .origin = math.vec3(0.0, -1.0, 0.0),
        .direction = math.vec3(0.0, 1.0, 0.0),
    };

    const result = ray.triangleIntersect(
        &a,
        &b,
        &c,
        true,
    ).?;
    const expected_t: f64 = 1;
    const expected_u: f64 = 0.3333;
    const expected_v: f64 = 0.3333;
    const expected_w: f64 = 0.3333;
    try testing.expect(f64, expected_u).eqlApprox(result.v[0], 1e-4);
    try testing.expect(f64, expected_v).eqlApprox(result.v[1], 1e-4);
    try testing.expect(f64, expected_w).eqlApprox(result.v[2], 1e-4);
    try testing.expect(f64, expected_t).eqlApprox(result.v[3], 1e-2);
}
