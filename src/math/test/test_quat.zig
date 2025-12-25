const std = @import("std");
const testing = @import("testing");
const math = @import("math");

test "zero_struct_overhead" {
    try testing.expect(usize, @alignOf(@Vector(4, f32))).eql(@alignOf(math.Quat));
    try testing.expect(usize, @sizeOf(@Vector(4, f32))).eql(@sizeOf(math.Quat));
}

test "init" {
    try testing.expect(math.Quat, math.quat(1, 2, 3, 4)).eql(math.Quat{
        .v = math.vec4(1, 2, 3, 4),
    });
}

test "inverse" {
    const q = math.Quat.init(1.0, 2.0, 3.0, 4.0);
    const expected = math.Quat.init(-0.1 / 3.0, -0.1 / 3.0 * 2.0, -0.1, 1.0 / 7.5);
    const actual = q.inverse();

    try testing.expect(math.Vec4, expected.v).eql(actual.v);
}

test "fromAxisAngle" {
    const expected = math.Quat.identity().rotateX(math.pi / 4.0);
    const actual = math.Quat.fromAxisAngle(math.vec3(1, 0, 0), math.pi / 4.0); // 45 degrees in radians (π/4) around the x-axis

    try testing.expect(math.Vec4, expected.v).eql(actual.v);
}

test "angleBetween" {
    const a = math.Quat.fromAxisAngle(math.vec3(1, 0, 0), 1.0);
    const b = math.Quat.fromAxisAngle(math.vec3(1, 0, 0), -1.0);

    try testing.expect(f32, math.Quat.angleBetween(&a, &b)).eql(2.0);
}

test "mul" {
    const a = math.Quat.init(1.0, 2.0, 3.0, 4.0);
    const b = a.inverse();
    const expected = math.Quat.identity();
    const actual = math.Quat.mul(&a, &b);

    try testing.expect(math.Vec4, expected.v).eql(actual.v);
}

test "add" {
    const a = math.Quat.init(1.0, 2.0, 3.0, 4.0);
    const b = math.Quat.init(5.0, 6.0, 7.0, 8.0);
    const expected = math.Quat.init(6.0, 8.0, 10.0, 12.0);
    const actual = math.Quat.add(&a, &b);

    try testing.expect(math.Vec4, expected.v).eql(actual.v);
}

test "sub" {
    const a = math.Quat.init(1.0, 2.0, 3.0, 4.0);
    const b = math.Quat.init(5.0, 6.0, 7.0, 8.0);
    const expected = math.Quat.init(-4.0, -4.0, -4.0, -4.0);
    const actual = math.Quat.sub(&a, &b);

    try testing.expect(math.Vec4, expected.v).eql(actual.v);
}

test "mulScalar" {
    const q = math.Quat.init(1.0, 2.0, 3.0, 4.0);
    const expected = math.Quat.init(2.0, 4.0, 6.0, 8.0);
    const actual = math.Quat.mulScalar(&q, 2.0);

    try testing.expect(math.Vec4, expected.v).eql(actual.v);
}

test "divScalar" {
    const q = math.Quat.init(1.0, 2.0, 3.0, 4.0);
    const expected = math.Quat.init(0.5, 1.0, 1.5, 2.0);
    const actual = math.Quat.divScalar(&q, 2.0);

    try testing.expect(math.Vec4, expected.v).eql(actual.v);
}

test "rotateX" {
    const expected = math.Quat.fromAxisAngle(math.vec3(1, 0, 0), math.pi / 4.0);
    const actual = math.Quat.identity().rotateX(math.pi / 4.0);

    try testing.expect(math.Vec4, expected.v).eql(actual.v);
}

test "rotateY" {
    const expected = math.Quat.fromAxisAngle(math.vec3(0, 1, 0), math.pi / 4.0);
    const actual = math.Quat.identity().rotateY(math.pi / 4.0);

    try testing.expect(math.Vec4, expected.v).eql(actual.v);
}

test "rotateZ" {
    const expected = math.Quat.fromAxisAngle(math.vec3(0, 0, 1), math.pi / 4.0);
    const actual = math.Quat.identity().rotateZ(math.pi / 4.0);

    try testing.expect(math.Vec4, expected.v).eql(actual.v);
}

test "slerp" {
    const a = math.Quat.init(1.0, 2.0, 3.0, 4.0);
    const b = math.Quat.init(5.0, 6.0, 7.0, 8.0);
    const expected = math.Quat.init(3.0, 4.0, 5.0, 6.0);
    const actual = math.Quat.slerp(&a, &b, 0.5);

    try testing.expect(math.Vec4, expected.v).eql(actual.v);
}

test "conjugate" {
    const q = math.Quat.init(1.0, 2.0, 3.0, 4.0);
    const expected = math.Quat.init(-1.0, -2.0, -3.0, 4.0);
    const actual = math.Quat.conjugate(&q);

    try testing.expect(math.Vec4, expected.v).eql(actual.v);
}

test "fromMat4" {
    const m = math.Mat4x4.rotateX(math.pi / 4.0);
    const q = math.Quat.fromMat(math.Mat4x4, &m);
    const expected = math.Quat.identity().rotateX(math.pi / 4.0);

    try testing.expect(math.Vec4, expected.v).eql(q.v);
}

test "fromEuler" {
    const q = math.Quat.fromEuler(math.pi / 4.0, 0.0, 0.0);
    const expected = math.Quat.identity().rotateX(math.pi / 4.0);

    try testing.expect(math.Vec4, expected.v).eql(q.v);
}

test "dot" {
    const a = math.Quat.init(1.0, 2.0, 3.0, 4.0);
    const b = math.Quat.init(5.0, 6.0, 7.0, 8.0);
    const expected = 70.0;
    const actual = math.Quat.dot(&a, &b);

    try testing.expect(f32, actual).eql(expected);
}

test "lerp" {
    const a = math.Quat.init(1.0, 2.0, 3.0, 4.0);
    const b = math.Quat.init(5.0, 6.0, 7.0, 8.0);
    const expected = math.Quat.init(3.0, 4.0, 5.0, 6.0);
    const actual = math.Quat.lerp(&a, &b, 0.5);

    try testing.expect(math.Vec4, expected.v).eql(actual.v);
}

test "len2" {
    const q = math.Quat.init(1.0, 2.0, 3.0, 4.0);
    const expected = 30.0;
    const actual = math.Quat.len2(&q);

    try testing.expect(f32, actual).eql(expected);
}

test "len" {
    const q = math.Quat.init(0.0, 0.0, 3.0, 4.0);
    const expected = 5.0;
    const actual = math.Quat.len(&q);

    try testing.expect(f32, actual).eql(expected);
}

test "normalize" {
    const q = math.Quat.init(0.0, 0.0, 3.0, 4.0);
    const expected = math.Quat.init(0.0, 0.0, 0.6, 0.8);
    const actual = math.Quat.normalize(&q);

    try testing.expect(math.Vec4, expected.v).eql(actual.v);
}
