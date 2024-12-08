const std = @import("std");

const vk = @import("vulkan");

const ResourceBufferUnmanaged = @import("../../resource_buffer.zig").ResourceBufferUnmanaged;
const Renderer = @import("../renderer.zig").Renderer;

pub const PipelineResourceBuffer = ResourceBufferUnmanaged(PipelineResource);
pub const PipelineResourceHandle = PipelineResourceBuffer.Handle;

pub const PipelineResource = struct {
    pipeline: vk.Pipeline,
    pipeline_layout: vk.PipelineLayout,

    pub fn init(self: *PipelineResource, renderer: *Renderer, vertex_src: []const u8, fragment_src: []const u8) !void {
        std.debug.assert(renderer.instance.handle != .null_handle);
        std.debug.assert(renderer.device.handle != .null_handle);

        std.debug.assert(vertex_src.len > 0);
        std.debug.assert(fragment_src.len > 0);

        self.pipeline = undefined;
        self.pipeline_layout = undefined;

        var vertex_shader: vk.ShaderModule = undefined;
        {
            const data: [*]const u32 = @alignCast(@ptrCast(vertex_src.ptr));
            const create_info = vk.ShaderModuleCreateInfo{
                .code_size = vertex_src.len,
                .p_code = data,
            };

            vertex_shader = try renderer.device.createShaderModule(&create_info, null);
        }

        var fragment_shader: vk.ShaderModule = undefined;
        {
            const data: [*]const u32 = @alignCast(@ptrCast(fragment_src.ptr));
            const create_info = vk.ShaderModuleCreateInfo{
                .code_size = fragment_src.len,
                .p_code = data,
            };

            fragment_shader = try renderer.device.createShaderModule(&create_info, null);
        }

        const shader_stages = [_]vk.PipelineShaderStageCreateInfo{
            .{
                .stage = vk.ShaderStageFlags{ .vertex_bit = true },
                .module = vertex_shader,
                .p_name = "main",
            },
            .{
                .stage = vk.ShaderStageFlags{ .fragment_bit = true },
                .module = fragment_shader,
                .p_name = "main",
            },
        };

        const input_assembly = vk.PipelineInputAssemblyStateCreateInfo{
            .topology = vk.PrimitiveTopology.triangle_list,
            .primitive_restart_enable = vk.FALSE,
        };

        const viewport_state = vk.PipelineViewportStateCreateInfo{
            .viewport_count = 1,
            .scissor_count = 1,
        };

        const color_blend_attachment = vk.PipelineColorBlendAttachmentState{
            .blend_enable = vk.FALSE,
            .color_write_mask = .{
                .r_bit = true,
                .g_bit = true,
                .b_bit = true,
                .a_bit = true,
            },
            .src_color_blend_factor = vk.BlendFactor.zero,
            .dst_color_blend_factor = vk.BlendFactor.zero,
            .src_alpha_blend_factor = vk.BlendFactor.zero,
            .dst_alpha_blend_factor = vk.BlendFactor.zero,
            .alpha_blend_op = vk.BlendOp.add,
            .color_blend_op = vk.BlendOp.add,
        };

        const color_blending = vk.PipelineColorBlendStateCreateInfo{
            .logic_op_enable = vk.FALSE,
            .logic_op = vk.LogicOp.copy,
            .attachment_count = 1,
            .p_attachments = @alignCast(@ptrCast(&color_blend_attachment)),
            .blend_constants = undefined,
        };

        const vertex_input_state = vk.PipelineVertexInputStateCreateInfo{};

        const multi_sample_state = vk.PipelineMultisampleStateCreateInfo{
            .sample_shading_enable = vk.FALSE,
            .rasterization_samples = vk.SampleCountFlags{ .@"1_bit" = true },
            .min_sample_shading = 1.0,
            .p_sample_mask = null,
            .alpha_to_coverage_enable = vk.FALSE,
            .alpha_to_one_enable = vk.FALSE,
        };

        const rasterization_state = vk.PipelineRasterizationStateCreateInfo{
            .depth_clamp_enable = vk.FALSE,
            .cull_mode = vk.CullModeFlags{},
            .front_face = vk.FrontFace.clockwise,
            .rasterizer_discard_enable = vk.FALSE,
            .polygon_mode = vk.PolygonMode.fill,
            .depth_bias_enable = vk.FALSE,
            .depth_bias_constant_factor = 0.0,
            .depth_bias_clamp = 0.0,
            .depth_bias_slope_factor = 0.0,
            .line_width = 1.0,
        };

        const formats: []const vk.Format = &.{renderer.format};

        const pipeline_rendering_info = vk.PipelineRenderingCreateInfo{
            .color_attachment_count = 1,
            .p_color_attachment_formats = formats.ptr,
            .depth_attachment_format = vk.Format.undefined,
            .view_mask = 0,
            .stencil_attachment_format = vk.Format.undefined,
        };

        const depth_test = std.mem.zeroInit(vk.PipelineDepthStencilStateCreateInfo, .{
            .s_type = .pipeline_depth_stencil_state_create_info,
            .depth_test_enable = vk.FALSE,
            .depth_write_enable = vk.FALSE,
            .depth_compare_op = vk.CompareOp.never,
            .depth_bounds_test_enable = vk.FALSE,
        });

        const pipeline_layout_create_info = std.mem.zeroInit(vk.PipelineLayoutCreateInfo, .{
            .s_type = .pipeline_layout_create_info,
        });

        self.pipeline_layout = try renderer.device.createPipelineLayout(&pipeline_layout_create_info, null);

        const dynamic_state: []const vk.DynamicState = &.{ .viewport, .scissor };
        const dynamic_state_create_info = vk.PipelineDynamicStateCreateInfo{
            .dynamic_state_count = 2,
            .p_dynamic_states = dynamic_state.ptr,
        };

        const pipeline_create_info = vk.GraphicsPipelineCreateInfo{
            .p_next = &pipeline_rendering_info,
            .stage_count = shader_stages.len,
            .flags = .{},
            .p_stages = &shader_stages,
            .p_vertex_input_state = &vertex_input_state,
            .p_input_assembly_state = &input_assembly,
            .p_viewport_state = &viewport_state,
            .p_rasterization_state = &rasterization_state,
            .p_multisample_state = &multi_sample_state,
            .p_color_blend_state = &color_blending,
            .p_depth_stencil_state = &depth_test,
            .layout = self.pipeline_layout,
            .subpass = 0,
            .base_pipeline_index = -1,
            .base_pipeline_handle = .null_handle,
            .p_tessellation_state = null,
            .render_pass = .null_handle,
            .p_dynamic_state = &dynamic_state_create_info,
        };
        _ = try renderer.device.createGraphicsPipelines(.null_handle, 1, @ptrCast(&pipeline_create_info), null, @ptrCast(&self.pipeline));

        renderer.device.destroyShaderModule(vertex_shader, null);
        renderer.device.destroyShaderModule(fragment_shader, null);
    }

    pub fn deinit(self: *PipelineResource, renderer: *Renderer) void {
        std.debug.assert(renderer.device.handle != .null_handle);
        std.debug.assert(self.pipeline_layout != .null_handle);
        std.debug.assert(self.pipeline != .null_handle);

        renderer.device.destroyPipelineLayout(self.pipeline_layout, null);
        renderer.device.destroyPipeline(self.pipeline, null);
    }
};
