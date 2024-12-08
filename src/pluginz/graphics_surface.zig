const EngineState = @import("internal/engine.zig").EngineState;
pub const GraphicsSurfaceResourceHandle = @import("internal/vulkan/surface.zig").SurfaceResourceHandle;
pub const GraphicsSurfaceConfig = @import("internal/vulkan/surface.zig").SurfaceConfig;
const SurfaceResource = @import("internal/vulkan/surface.zig").SurfaceResource;
const WindowResourceHandle = @import("window.zig").WindowResourceHandle;

pub const GraphicsSurface = struct {
    pub fn init(handle: WindowResourceHandle, config: GraphicsSurfaceConfig) !GraphicsSurfaceResourceHandle {
        const window = EngineState.instance.platform.windows.at(handle);
        var surface: *SurfaceResource = undefined;
        const surface_handle = try EngineState.instance.renderer.surfaces.alloc(&surface);

        try surface.init(&EngineState.instance.renderer, EngineState.instance.allocator, window, config);

        return surface_handle;
    }

    pub fn deinit(handle: GraphicsSurfaceResourceHandle) void {
        const surface = EngineState.instance.renderer.surfaces.at(handle);

        SurfaceResource.deinit(surface, &EngineState.instance.renderer, EngineState.instance.allocator);

        EngineState.instance.platform.windows.dealloc(handle);
    }

    pub fn begin(handle: GraphicsSurfaceResourceHandle) void {
        const surface = EngineState.instance.renderer.surfaces.at(handle);
        EngineState.instance.renderer.surface = surface;
    }

    pub fn end() void {
        EngineState.instance.renderer.surface = undefined;
    }
};
