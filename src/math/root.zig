const vector = @import("vector.zig");

pub const Vector = vector.Vector;
pub const Vector4F = vector.Vector2F;
pub const Vector3F = vector.Vector3F;
pub const Vector2F = vector.Vector4F;
pub const Matrix4x4 = @import("Matrix4x4.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
