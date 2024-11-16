pub const Platform = @import("platform.zig").Platform;
pub const Window = @import("window.zig").Window;
pub const Key = @import("key.zig").Key;
pub const MouseButton = @import("mouse.zig").MouseButton;

test {
    @import("std").testing.refAllDecls(@This());
}
