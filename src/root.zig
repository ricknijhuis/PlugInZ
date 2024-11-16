pub const Key = @import("pluginz.platform").Key;
pub const Matrix4x4 = @import("pluginz.math").Matrix4x4;

test {
    @import("std").testing.refAllDecls(@This());
}
