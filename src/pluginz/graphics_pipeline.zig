const EngineState = @import("internal/engine.zig").EngineState;
pub const GraphicsPipelineResourceHandle = @import("internal/vulkan/pipeline.zig").PipelineResourceHandle;
const PipelineResource = @import("internal/vulkan/pipeline.zig").PipelineResource;

pub const GraphicsPipeline = struct {
    pub fn init(vertex_src: []const u8, fragment_src: []const u8) !GraphicsPipelineResourceHandle {
        var pipeline: *PipelineResource = undefined;
        const pipeline_handle = try EngineState.instance.renderer.pipelines.alloc(&pipeline);

        try pipeline.init(&EngineState.instance.renderer, vertex_src, fragment_src);

        return pipeline_handle;
    }

    pub fn begin(handle: GraphicsPipelineResourceHandle) void {
        const pipeline = EngineState.instance.renderer.pipelines.at(handle);
        EngineState.instance.renderer.pipeline = pipeline;
    }

    pub fn end() void {
        EngineState.instance.renderer.pipeline = undefined;
    }
};
