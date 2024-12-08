const GraphicsPipelineResourceHandle = @import("graphics_pipeline.zig").GraphicsPipelineResourceHandle;
const GraphicsSurfaceResourceHandle = @import("graphics_surface.zig").GraphicsSurfaceResourceHandle;
const EngineState = @import("internal/engine.zig").EngineState;

pub const Renderer = struct {
    pub fn clearColor(r: f32, g: f32, b: f32, a: f32) !void {
        _ = a; // autofix
        _ = b; // autofix
        _ = g; // autofix
        _ = r; // autofix

    }

    pub fn draw() !void {
        try EngineState.instance.renderer.draw();
    }
};
