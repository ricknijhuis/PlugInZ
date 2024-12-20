const std = @import("std");

pub fn Vector(comptime Scalar: type, dimensions: u32) type {
    return extern struct {
        data: @Vector(dimensions, Scalar),

        const Self = @This();
        const VecT = @Vector(dimensions, Scalar);

        pub usingnamespace switch (dimensions) {
            inline 2 => struct {
                pub inline fn init(xs: Scalar, ys: Scalar) Self {
                    return .{ .data = .{ xs, ys } };
                }

                pub inline fn x(self: Self) Scalar {
                    return self.data[0];
                }

                pub inline fn y(self: Self) Scalar {
                    return self.data[1];
                }
            },
            inline 3 => struct {
                pub inline fn init(xs: Scalar, ys: Scalar, zs: Scalar) Self {
                    return .{ .data = .{ xs, ys, zs } };
                }

                pub inline fn x(self: Self) Scalar {
                    return self.data[0];
                }

                pub inline fn y(self: Self) Scalar {
                    return self.data[1];
                }

                pub inline fn z(self: Self) Scalar {
                    return self.data[2];
                }
            },
            inline 4 => struct {
                pub inline fn init(xs: Scalar, ys: Scalar, zs: Scalar, ws: Scalar) Self {
                    return .{ .data = .{ xs, ys, zs, ws } };
                }

                pub inline fn x(self: Self) Scalar {
                    return self.data[0];
                }

                pub inline fn y(self: Self) Scalar {
                    return self.data[1];
                }

                pub inline fn z(self: Self) Scalar {
                    return self.data[2];
                }

                pub inline fn w(self: Self) Scalar {
                    return self.data[3];
                }
            },
            else => {
                @compileError("Dimension not supported");
            },
        };

        pub inline fn splat(value: Scalar) Self {
            return .{ .data = @splat(value) };
        }

        pub inline fn magnitude(self: Self) Scalar {
            return std.math.sqrt(@reduce(.Add, self.data * self.data));
        }

        pub inline fn normalize(self: Self) Self {
            return self.div(Self.splat(self.magnitude()));
        }

        pub inline fn add(self: Self, other: Self) Self {
            return .{ .data = self.data + other.data };
        }

        pub inline fn sub(self: Self, other: Self) Self {
            return .{ .data = self.data - other.data };
        }

        pub inline fn mul(self: Self, other: Self) Self {
            return .{ .data = self.data * other.data };
        }

        pub inline fn div(self: Self, other: Self) Self {
            return .{ .data = self.data / other.data };
        }

        pub inline fn dot(self: Self, other: Self) Scalar {
            return @reduce(.Add, self.mul(other).data);
        }

        pub inline fn mulScalar(self: Self, scalar: Scalar) Self {
            return .{ .data = self.data * @as(VecT, @splat(scalar)) };
        }

        pub inline fn cross(self: Self, other: Self) Self {
            return switch (dimensions) {
                inline 3 => .{ .data = (@shuffle(Scalar, self.data, undefined, [3]i32{ 1, 2, 0 }) * @shuffle(Scalar, other.data, undefined, [3]i32{ 2, 0, 1 })) -
                    (@shuffle(Scalar, self.data, undefined, [3]i32{ 2, 0, 1 }) * @shuffle(Scalar, other.data, undefined, [3]i32{ 1, 2, 0 })) },
                else => {
                    @compileError("Dimension not supported for cross product");
                },
            };
        }
    };
}

const Vector4F = Vector(f32, 4);
const Vector3F = Vector(f32, 3);
const Vector2F = Vector(f32, 2);

// Vector2F tests
test "Vec2 can init" {
    const testing = std.testing;

    const vec = Vector2F.init(1.0, 2.0);

    try testing.expectApproxEqAbs(vec.x(), 1.0, 0.001);
    try testing.expectApproxEqAbs(vec.y(), 2.0, 0.001);
}

test "Vec2 can splat" {
    const testing = std.testing;

    const vec = Vector2F.splat(1.0);

    try testing.expectApproxEqAbs(vec.x(), 1.0, 0.001);
    try testing.expectApproxEqAbs(vec.y(), 1.0, 0.001);
}

test "Vec2 magnitude returns correct value" {
    const testing = std.testing;

    const vec = Vector2F.init(2.0, 2.0);
    const result = vec.magnitude();

    try testing.expectApproxEqAbs(result, 2.82842712474619, 0.001);
}

test "Vec2 add returns correct value" {
    const testing = std.testing;

    const vec = Vector2F.init(1.0, 2.0);
    const other = Vector2F.init(2.0, 3.0);
    const result = vec.add(other);

    try testing.expectApproxEqAbs(result.x(), 3.0, 0.001);
    try testing.expectApproxEqAbs(result.y(), 5.0, 0.001);
}

test "Vec2 subtract returns correct value" {
    const testing = std.testing;

    const vec = Vector2F.init(1.0, 2.0);
    const other = Vector2F.init(2.0, 3.0);
    const result = vec.sub(other);

    try testing.expectApproxEqAbs(result.x(), -1.0, 0.001);
    try testing.expectApproxEqAbs(result.y(), -1.0, 0.001);
}

test "Vec2 mul returns correct value" {
    const testing = std.testing;

    const vec = Vector2F.init(1.0, 2.0);
    const other = Vector2F.init(2.0, 3.0);
    const result = vec.mul(other);

    try testing.expectApproxEqAbs(result.x(), 2.0, 0.001);
    try testing.expectApproxEqAbs(result.y(), 6.0, 0.001);
}

test "Vec2 div returns correct value" {
    const testing = std.testing;

    const vec = Vector2F.init(1.0, 2.0);
    const other = Vector2F.init(2.0, 3.0);
    const result = vec.div(other);

    try testing.expectApproxEqAbs(result.x(), 0.5, 0.001);
    try testing.expectApproxEqAbs(result.y(), 0.66666666666666666666666666666667, 0.001);
}

test "Vec2 dot returns correct value" {
    const testing = std.testing;

    const vec = Vector2F.init(1.0, 2.0);
    const other = Vector2F.init(2.0, 3.0);
    const result = vec.dot(other);

    try testing.expectApproxEqAbs(result, 8.0, 0.001);
}

// Vector3F tests
test "Vec3 can init" {
    const testing = std.testing;

    const vec = Vector3F.init(1.0, 2.0, 3.0);

    try testing.expectApproxEqAbs(vec.x(), 1.0, 0.001);
    try testing.expectApproxEqAbs(vec.y(), 2.0, 0.001);
    try testing.expectApproxEqAbs(vec.z(), 3.0, 0.001);
}

test "Vec3 can splat" {
    const testing = std.testing;

    const vec = Vector3F.splat(1.0);

    try testing.expectApproxEqAbs(vec.x(), 1.0, 0.001);
    try testing.expectApproxEqAbs(vec.y(), 1.0, 0.001);
    try testing.expectApproxEqAbs(vec.z(), 1.0, 0.001);
}

test "Vec3 magnitude returns correct value" {
    const testing = std.testing;

    const vec = Vector3F.init(2.0, 2.0, 2.0);
    const result = vec.magnitude();

    try testing.expectApproxEqAbs(result, 3.464101615137755, 0.001);
}

test "Vec3 add returns correct value" {
    const testing = std.testing;

    const vec = Vector3F.init(1.0, 2.0, 3.0);
    const other = Vector3F.init(3.0, 4.0, 5.0);
    const result = vec.add(other);
    try testing.expectApproxEqAbs(result.x(), 4.0, 0.001);
    try testing.expectApproxEqAbs(result.y(), 6.0, 0.001);
    try testing.expectApproxEqAbs(result.z(), 8.0, 0.001);
}

test "Vec3 subtract returns correct value" {
    const testing = std.testing;

    const vec = Vector3F.init(1.0, 2.0, 3.0);
    const other = Vector3F.init(3.0, 4.0, 5.0);
    const result = vec.sub(other);

    try testing.expectApproxEqAbs(result.x(), -2.0, 0.001);
    try testing.expectApproxEqAbs(result.y(), -2.0, 0.001);
    try testing.expectApproxEqAbs(result.z(), -2.0, 0.001);
}

test "Vec3 mul returns correct value" {
    const testing = std.testing;

    const vec = Vector3F.init(1.0, 2.0, 3.0);
    const other = Vector3F.init(3.0, 4.0, 5.0);
    const result = vec.mul(other);

    try testing.expectApproxEqAbs(result.x(), 3.0, 0.001);
    try testing.expectApproxEqAbs(result.y(), 8.0, 0.001);
    try testing.expectApproxEqAbs(result.z(), 15.0, 0.001);
}

test "Vec3 div returns correct value" {
    const testing = std.testing;

    const vec = Vector3F.init(1.0, 2.0, 3.0);
    const other = Vector3F.init(3.0, 4.0, 5.0);
    const result = vec.div(other);

    try testing.expectApproxEqAbs(result.x(), 0.33333333333333333333333333333333, 0.001);
    try testing.expectApproxEqAbs(result.y(), 0.5, 0.001);
    try testing.expectApproxEqAbs(result.z(), 0.6, 0.001);
}

test "Vec3 dot returns correct value" {
    const testing = std.testing;

    const vec = Vector3F.init(1.0, 2.0, 3.0);
    const other = Vector3F.init(3.0, 4.0, 5.0);
    const result = vec.dot(other);

    try testing.expectEqual(result, 26.0);
}

test "Vec3 cross returns correct value" {
    const testing = std.testing;

    const vec = Vector3F.init(1.0, 2.0, 3.0);
    const other = Vector3F.init(3.0, 4.0, 5.0);
    const result = vec.cross(other);

    try testing.expectApproxEqAbs(result.x(), -2.0, 0.001);
    try testing.expectApproxEqAbs(result.y(), 4.0, 0.001);
    try testing.expectApproxEqAbs(result.z(), -2.0, 0.001);
}

// Vector4F tests
test "Vec4 can init" {
    const testing = std.testing;

    const vec = Vector4F.init(1.0, 2.0, 3.0, 4.0);

    try testing.expectApproxEqAbs(vec.x(), 1.0, 0.001);
    try testing.expectApproxEqAbs(vec.y(), 2.0, 0.001);
    try testing.expectApproxEqAbs(vec.z(), 3.0, 0.001);
    try testing.expectApproxEqAbs(vec.w(), 4.0, 0.001);
}

test "Vec4 can splat" {
    const testing = std.testing;

    const vec = Vector4F.splat(1.0);

    try testing.expectApproxEqAbs(vec.x(), 1.0, 0.001);
    try testing.expectApproxEqAbs(vec.y(), 1.0, 0.001);
    try testing.expectApproxEqAbs(vec.z(), 1.0, 0.001);
    try testing.expectApproxEqAbs(vec.w(), 1.0, 0.001);
}

test "Vec4 magnitude returns correct value" {
    const testing = std.testing;

    const vec = Vector4F.init(2.0, 2.0, 2.0, 2.0);
    const result = vec.magnitude();

    try testing.expectEqual(result, 4.0);
}

test "Vec4 add returns correct value" {
    const testing = std.testing;

    const vec = Vector4F.init(1.0, 2.0, 3.0, 4.0);
    const other = Vector4F.init(4.0, 5.0, 6.0, 7.0);
    const result = vec.add(other);
    try testing.expectApproxEqAbs(result.x(), 5.0, 0.001);
    try testing.expectApproxEqAbs(result.y(), 7.0, 0.001);
    try testing.expectApproxEqAbs(result.z(), 9.0, 0.001);
    try testing.expectApproxEqAbs(result.w(), 11.0, 0.001);
}

test "Vec4 subtract returns correct value" {
    const testing = std.testing;

    const vec = Vector4F.init(1.0, 2.0, 3.0, 4.0);
    const other = Vector4F.init(4.0, 5.0, 6.0, 7.0);
    const result = vec.sub(other);

    try testing.expectApproxEqAbs(result.x(), -3.0, 0.001);
    try testing.expectApproxEqAbs(result.y(), -3.0, 0.001);
    try testing.expectApproxEqAbs(result.z(), -3.0, 0.001);
    try testing.expectApproxEqAbs(result.w(), -3.0, 0.001);
}

test "Vec4 mul returns correct value" {
    const testing = std.testing;

    const vec = Vector4F.init(1.0, 2.0, 3.0, 4.0);
    const other = Vector4F.init(4.0, 5.0, 6.0, 7.0);
    const result = vec.mul(other);

    try testing.expectApproxEqAbs(result.x(), 4.0, 0.001);
    try testing.expectApproxEqAbs(result.y(), 10.0, 0.001);
    try testing.expectApproxEqAbs(result.z(), 18.0, 0.001);
    try testing.expectApproxEqAbs(result.w(), 28.0, 0.001);
}

test "Vec4 div returns correct value" {
    const testing = std.testing;

    const vec = Vector4F.init(1.0, 2.0, 3.0, 4.0);
    const other = Vector4F.init(4.0, 5.0, 6.0, 7.0);
    const result = vec.div(other);

    try testing.expectApproxEqAbs(result.x(), 0.25, 0.001);
    try testing.expectApproxEqAbs(result.y(), 0.4, 0.001);
    try testing.expectApproxEqAbs(result.z(), 0.5, 0.001);
    try testing.expectApproxEqAbs(result.w(), 0.57142857142857142857142857142857, 0.001);
}

test "Vec4 dot returns correct value" {
    const testing = std.testing;

    const vec = Vector4F.init(1.0, 2.0, 3.0, 4.0);
    const other = Vector4F.init(4.0, 5.0, 6.0, 7.0);
    const result = vec.dot(other);

    try testing.expectEqual(result, 60.0);
}

// examples
test "Get scalar projection" {
    // a = (x = 1.0, y = 1.0)
    // b = (x = 2.0, y = 4.0)
    //          y
    //          |
    //          |       b
    //          | a
    //  --------|--------- x
    //          |
    //          |
    //          |
    const testing = std.testing;
    const a = Vector2F.init(1.0, 1.0);
    const b = Vector2F.init(2.0, 4.0);

    const a_normalized = a.normalize();
    const result = a_normalized.dot(b);

    try testing.expectApproxEqAbs(result, 4.242640687119285, 0.001);
}

test "Get vector projection" {
    // a = (x = 1.0, y = 1.0)
    // b = (x = 2.0, y = 4.0)
    //          y
    //          |    b
    //          |
    //          | a
    //  --------|--------- x
    //          |
    //          |
    //          |
    const testing = std.testing;
    const a = Vector2F.init(1.0, 1.0);
    const b = Vector2F.init(2.0, 4.0);

    const a_normalized = a.normalize();
    const scalar_projection = a_normalized.dot(b);
    const result = a_normalized.mul(Vector2F.splat(scalar_projection));
    try testing.expectApproxEqAbs(result.x(), 2.99999976e+00, 0.001);
    try testing.expectApproxEqAbs(result.y(), 2.99999976e+00, 0.001);
}
