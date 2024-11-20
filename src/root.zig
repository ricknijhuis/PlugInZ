pub const Platform = @import("platform.zig").Platform;
pub const Window = @import("window.zig").Window;
pub const Renderer = @import("renderer.zig").Renderer;

test {
    @import("std").testing.refAllDecls(@This());
}
