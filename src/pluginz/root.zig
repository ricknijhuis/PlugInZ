pub const Engine = @import("engine.zig").Engine;
pub const EngineConfig = @import("engine.zig").EngineConfig;
pub const GraphicsPipeline = @import("graphics_pipeline.zig").GraphicsPipeline;
pub const GraphicsPipelineResourceHandle = @import("graphics_pipeline.zig").GraphicsPipelineResourceHandle;
pub const GraphicsSurface = @import("graphics_surface.zig").GraphicsSurface;
pub const GraphicsSurfaceResourceHandle = @import("graphics_surface.zig").GraphicsSurfaceResourceHandle;
pub const Matrix4x4F = @import("math/matrix4x4.zig").Matrix4x4F;
pub const Vector = @import("math/vector.zig").Vector;
pub const Renderer = @import("renderer.zig").Renderer;
pub const ResourceBuffer = @import("resource_buffer.zig").ResourceBuffer;
pub const ResourceBufferUnmanaged = @import("resource_buffer.zig").ResourceBufferUnmanaged;
pub const Window = @import("window.zig").Window;
pub const WindowConfig = @import("window.zig").WindowConfig;
pub const WindowResizeCallbackFn = @import("window.zig").WindowResizeCallbackFn;
pub const WindowResourceHandle = @import("window.zig").WindowResourceHandle;

pub const Vec4F32 = @import("math/vector.zig").Vector(4, f32);
pub const Vec3F32 = @import("math/vector.zig").Vector(3, f32);
pub const Vec2F32 = @import("math/vector.zig").Vector(2, f32);
pub const Vec4I32 = @import("math/vector.zig").Vector(4, i32);
pub const Vec3I32 = @import("math/vector.zig").Vector(3, i32);
pub const Vec2I23 = @import("math/vector.zig").Vector(2, i32);

test {
    @import("std").testing.refAllDecls(@This());
}
