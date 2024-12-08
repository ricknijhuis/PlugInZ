const std = @import("std");

const vector = @import("vector.zig");
const Vector = vector.Vector;

const Matrix4x4F = struct {
    const ColT = @Vector(4, f32);
    const VecT = Vector(f32, 3);

    data: [4]ColT,

    // Uses rows instead of columns as params for more intuitive initialization
    pub inline fn init(r0: ColT, r1: ColT, r2: ColT, r3: ColT) Matrix4x4F {
        return .{
            .data = .{
                .{ r0[0], r1[0], r2[0], r3[0] }, // r0.1  r0.2  r0.3  r0.4
                .{ r0[1], r1[1], r2[1], r3[1] }, // r1.1  r1.2  r1.3  r1.4
                .{ r0[2], r1[2], r2[2], r3[2] }, // r2.1  r2.2  r2.3  r2.4
                .{ r0[3], r1[3], r2[3], r3[3] }, // r3.1  r3.2  r3.3  r3.4
            },
        };
    }

    pub inline fn identity() Matrix4x4F {
        return .{
            .data = .{
                .{ 1.0, 0.0, 0.0, 0.0 },
                .{ 0.0, 1.0, 0.0, 0.0 },
                .{ 0.0, 0.0, 1.0, 0.0 },
                .{ 0.0, 0.0, 0.0, 1.0 },
            },
        };
    }

    pub inline fn translation(vec: VecT) Matrix4x4F {
        return .{
            .data = .{
                .{ 1.0, 0.0, 0.0, 0.0 },
                .{ 0.0, 1.0, 0.0, 0.0 },
                .{ 0.0, 0.0, 1.0, 0.0 },
                .{ vec.x(), vec.y(), vec.z(), 1.0 },
            },
        };
    }

    pub inline fn scale(magnitude: VecT) Matrix4x4F {
        return .{
            .data = .{
                .{ magnitude.x(), 0.0, 0.0, 0.0 },
                .{ 0.0, magnitude.y(), 0.0, 0.0 },
                .{ 0.0, 0.0, magnitude.z(), 0.0 },
                .{ 0.0, 0.0, 0.0, 1.0 },
            },
        };
    }

    pub inline fn rotation(angle: f32, axis: VecT) Matrix4x4F {
        _ = angle; // autofix
        _ = axis; // autofix
    }

    pub inline fn mul(self: Matrix4x4F, other: Matrix4x4F) Matrix4x4F {
        _ = self; // autofix
        _ = other; // autofix
    }
};

test "Can mat4 init accepts rows and converts to correct column major layout" {
    const testing = std.testing;
    const result = Matrix4x4F.init(
        .{ 1.0, 5.0, 9.0, 13.0 },
        .{ 2.0, 6.0, 10.0, 14.0 },
        .{ 3.0, 7.0, 11.0, 15.0 },
        .{ 4.0, 8.0, 12.0, 16.0 },
    );

    // column 1
    try testing.expectEqual(result.data[0][0], 1.0);
    try testing.expectEqual(result.data[0][1], 2.0);
    try testing.expectEqual(result.data[0][2], 3.0);
    try testing.expectEqual(result.data[0][3], 4.0);

    // column 2
    try testing.expectEqual(result.data[1][0], 5.0);
    try testing.expectEqual(result.data[1][1], 6.0);
    try testing.expectEqual(result.data[1][2], 7.0);
    try testing.expectEqual(result.data[1][3], 8.0);

    // column 3
    try testing.expectEqual(result.data[2][0], 9.0);
    try testing.expectEqual(result.data[2][1], 10.0);
    try testing.expectEqual(result.data[2][2], 11.0);
    try testing.expectEqual(result.data[2][3], 12.0);

    // column 4
    try testing.expectEqual(result.data[3][0], 13.0);
    try testing.expectEqual(result.data[3][1], 14.0);
    try testing.expectEqual(result.data[3][2], 15.0);
    try testing.expectEqual(result.data[3][3], 16.0);
}

test "Mat4 Identity returns identity matrix" {
    const testing = std.testing;

    const result = Matrix4x4F.identity();

    // column 1
    try testing.expectEqual(result.data[0][0], 1.0);
    try testing.expectEqual(result.data[0][1], 0.0);
    try testing.expectEqual(result.data[0][2], 0.0);
    try testing.expectEqual(result.data[0][3], 0.0);

    // column 2
    try testing.expectEqual(result.data[1][0], 0.0);
    try testing.expectEqual(result.data[1][1], 1.0);
    try testing.expectEqual(result.data[1][2], 0.0);
    try testing.expectEqual(result.data[1][3], 0.0);

    // column 3
    try testing.expectEqual(result.data[2][0], 0.0);
    try testing.expectEqual(result.data[2][1], 0.0);
    try testing.expectEqual(result.data[2][2], 1.0);
    try testing.expectEqual(result.data[2][3], 0.0);

    // column 4
    try testing.expectEqual(result.data[3][0], 0.0);
    try testing.expectEqual(result.data[3][1], 0.0);
    try testing.expectEqual(result.data[3][2], 0.0);
    try testing.expectEqual(result.data[3][3], 1.0);
}

test "Mat4 translation returns translation matrix" {
    const testing = std.testing;
    const Vector3F = vector.Vector3F;

    const vec = Vector3F.init(1.5, 1.6, 1.7);
    const result = Matrix4x4F.translation(vec);

    // column 1
    try testing.expectEqual(result.data[0][0], 1.0);
    try testing.expectEqual(result.data[0][1], 0.0);
    try testing.expectEqual(result.data[0][2], 0.0);
    try testing.expectEqual(result.data[0][3], 0.0);
    // column 2
    try testing.expectEqual(result.data[1][0], 0.0);
    try testing.expectEqual(result.data[1][1], 1.0);
    try testing.expectEqual(result.data[1][2], 0.0);
    try testing.expectEqual(result.data[1][3], 0.0);
    // column 3
    try testing.expectEqual(result.data[2][0], 0.0);
    try testing.expectEqual(result.data[2][1], 0.0);
    try testing.expectEqual(result.data[2][2], 1.0);
    try testing.expectEqual(result.data[2][3], 0.0);
    // column 4
    try testing.expectEqual(result.data[3][0], 1.5);
    try testing.expectEqual(result.data[3][1], 1.6);
    try testing.expectEqual(result.data[3][2], 1.7);
    try testing.expectEqual(result.data[3][3], 1.0);
}

test "Mat4 scale returns translation matrix" {
    const testing = std.testing;
    const Vector3F = vector.Vector3F;

    const vec = Vector3F.init(1.5, 1.6, 1.7);
    const result = Matrix4x4F.scale(vec);

    // column 1
    try testing.expectEqual(result.data[0][0], 1.5);
    try testing.expectEqual(result.data[0][1], 0.0);
    try testing.expectEqual(result.data[0][2], 0.0);
    try testing.expectEqual(result.data[0][3], 0.0);
    // column 2
    try testing.expectEqual(result.data[1][0], 0.0);
    try testing.expectEqual(result.data[1][1], 1.6);
    try testing.expectEqual(result.data[1][2], 0.0);
    try testing.expectEqual(result.data[1][3], 0.0);
    // column 3
    try testing.expectEqual(result.data[2][0], 0.0);
    try testing.expectEqual(result.data[2][1], 0.0);
    try testing.expectEqual(result.data[2][2], 1.7);
    try testing.expectEqual(result.data[2][3], 0.0);
    // column 4
    try testing.expectEqual(result.data[3][0], 0.0);
    try testing.expectEqual(result.data[3][1], 0.0);
    try testing.expectEqual(result.data[3][2], 0.0);
    try testing.expectEqual(result.data[3][3], 1.0);
}
