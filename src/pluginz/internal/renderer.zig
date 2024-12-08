const std = @import("std");

const vk = @import("vulkan");

const Instance = @import("vulkan/instance.zig").Instance;
const LogicalDevice = @import("vulkan/logical_device.zig").LogicalDevice;
const PhysicalDevice = @import("vulkan/physical_device.zig").PhysicalDevice;
const PipelineResourceBuffer = @import("vulkan/pipeline.zig").PipelineResourceBuffer;
const PipelineResource = @import("vulkan/pipeline.zig").PipelineResource;
const SurfaceResourceBuffer = @import("vulkan/surface.zig").SurfaceResourceBuffer;
const SurfaceResource = @import("vulkan/surface.zig").SurfaceResource;
const vkw = @import("vulkan/wrapper.zig");

pub const Renderer = struct {
    base: vkw.BaseDispatch,
    instance: vkw.InstanceProxy,
    debug_messenger: vk.DebugUtilsMessengerEXT,

    device: vkw.DeviceProxy,
    device_graphics_queue: vk.Queue,
    device_present_queue: vk.Queue,
    device_graphics_queue_family_index: u32,
    device_present_queue_family_index: u32,

    // All physical devices, sorted from best to worst desc
    physical_devices: []PhysicalDevice,
    // Index of picked device
    physical_device: u32,

    // format shared between swapchains
    format: vk.Format,

    // All surfaces
    surfaces: SurfaceResourceBuffer,
    // Current active surface
    surface: *SurfaceResource,

    // All pipelines
    pipelines: PipelineResourceBuffer,
    // Current active pipeline
    pipeline: *PipelineResource,

    pub fn init(self: *Renderer, allocator: std.mem.Allocator) !void {
        self.base = undefined;
        self.instance = undefined;
        self.debug_messenger = .null_handle;

        self.device = undefined;
        self.device_graphics_queue = undefined;
        self.device_present_queue = undefined;
        self.device_graphics_queue_family_index = undefined;
        self.device_present_queue_family_index = undefined;
        self.physical_devices = undefined;
        self.physical_device = undefined;
        self.format = undefined;
        self.surfaces = undefined;
        self.pipelines = undefined;

        try Instance.init(self, allocator);
        errdefer Instance.deinit(self, allocator);

        const physical_devices = try self.instance.enumeratePhysicalDevicesAlloc(allocator);
        defer allocator.free(physical_devices);

        self.physical_devices = try allocator.alloc(PhysicalDevice, physical_devices.len);

        for (self.physical_devices, physical_devices) |*physical_device, vk_device| {
            try physical_device.init(allocator, self.instance, vk_device);
        }
        errdefer self.deinitPhysicalDevices(allocator);

        try LogicalDevice.init(self, allocator);
        errdefer LogicalDevice.deinit(self, allocator);

        self.surfaces = try SurfaceResourceBuffer.init(allocator, 8);
        self.pipelines = try PipelineResourceBuffer.init(allocator, 8);
        self.format = vk.Format.b8g8r8a8_srgb;
    }

    pub fn draw(self: *Renderer) !void {
        const current_frame = self.surface.current_frame % self.surface.frames_in_flight;
        _ = try self.device.waitForFences(
            1,
            @ptrCast(&self.surface.fences[current_frame]),
            vk.TRUE,
            std.math.maxInt(u64),
        );
        try self.device.resetFences(1, @ptrCast(&self.surface.fences[current_frame]));

        const result = try self.device.acquireNextImageKHR(
            self.surface.swapchain,
            1000000000,
            self.surface.swapchain_semaphores[current_frame],
            .null_handle,
        );
        if (result.result != .success) {
            std.log.debug("Error: {}", .{result.result});
            return error.ImageAcquireFailed;
        }
        const image_index = result.image_index;

        const cmd_buffer_begin_info = vk.CommandBufferBeginInfo{
            .flags = .{ .one_time_submit_bit = true },
        };

        const cmd = self.surface.command_buffers[current_frame];

        try self.device.resetCommandBuffer(cmd, .{});
        try self.device.beginCommandBuffer(cmd, &cmd_buffer_begin_info);

        const current_img = self.surface.images[image_index];
        self.transitionImage(cmd, current_img, vk.ImageLayout.undefined, vk.ImageLayout.general);

        const color = vk.ClearColorValue{
            .float_32 = .{ 1.0, 0.0, 0.0, 1.0 },
        };

        const subresource_range = vk.ImageSubresourceRange{
            .aspect_mask = .{ .color_bit = true },
            .base_mip_level = 0,
            .level_count = vk.REMAINING_MIP_LEVELS,
            .base_array_layer = 0,
            .layer_count = vk.REMAINING_ARRAY_LAYERS,
        };

        self.device.cmdClearColorImage(
            cmd,
            current_img,
            vk.ImageLayout.general,
            &color,
            1,
            @ptrCast(&subresource_range),
        );

        self.transitionImage(
            cmd,
            current_img,
            vk.ImageLayout.general,
            vk.ImageLayout.present_src_khr,
        );
        try self.device.endCommandBuffer(cmd);

        const cmd_submit_info = vk.CommandBufferSubmitInfo{
            .command_buffer = cmd,
            .device_mask = 0,
        };

        const wait_info = vk.SemaphoreSubmitInfo{
            .semaphore = self.surface.swapchain_semaphores[current_frame],
            .stage_mask = .{ .color_attachment_output_bit = true },
            .device_index = 0,
            .value = 1,
        };

        const signal_info = vk.SemaphoreSubmitInfo{
            .semaphore = self.surface.render_semaphores[current_frame],
            .stage_mask = .{ .all_graphics_bit = true },
            .device_index = 0,
            .value = 1,
        };

        const submit_info = vk.SubmitInfo2{
            .wait_semaphore_info_count = 1,
            .p_wait_semaphore_infos = @ptrCast(&wait_info),
            .command_buffer_info_count = 1,
            .p_command_buffer_infos = @ptrCast(&cmd_submit_info),
            .signal_semaphore_info_count = 1,
            .p_signal_semaphore_infos = @ptrCast(&signal_info),
        };

        try self.device.queueSubmit2(
            self.device_graphics_queue,
            1,
            @ptrCast(&submit_info),
            self.surface.fences[current_frame],
        );

        const present_info = vk.PresentInfoKHR{
            .wait_semaphore_count = 1,
            .p_wait_semaphores = @ptrCast(&self.surface.render_semaphores[current_frame]),
            .swapchain_count = 1,
            .p_swapchains = @ptrCast(&self.surface.swapchain),
            .p_image_indices = @ptrCast(&image_index),
        };

        _ = try self.device.queuePresentKHR(self.device_graphics_queue, &present_info);
        // Ensure wrap around
        self.surface.current_frame = self.surface.current_frame +% 1;
    }

    pub fn deinit(self: *Renderer, allocator: std.mem.Allocator) void {
        self.deinitPipelines(allocator);

        self.deinitSurfaces(allocator);

        LogicalDevice.deinit(self, allocator);

        self.deinitPhysicalDevices(allocator);

        Instance.deinit(self, allocator);
    }

    fn deinitPhysicalDevices(self: *Renderer, allocator: std.mem.Allocator) void {
        for (self.physical_devices) |*physical_device| {
            physical_device.deinit(allocator);
        }
        allocator.free(self.physical_devices);
    }

    fn deinitSurfaces(self: *Renderer, allocator: std.mem.Allocator) void {
        for (self.surfaces.getAll()) |*surface| {
            surface.deinit(self, allocator);
        }
        self.surfaces.deinit(allocator);
    }

    fn deinitPipelines(self: *Renderer, allocator: std.mem.Allocator) void {
        for (self.pipelines.getAll()) |*pipeline| {
            pipeline.deinit(self);
        }

        self.pipelines.deinit(allocator);
    }

    fn transitionImage(self: *Renderer, cmd: vk.CommandBuffer, image: vk.Image, old_layout: vk.ImageLayout, new_layout: vk.ImageLayout) void {
        const img_barrier = vk.ImageMemoryBarrier2{
            .src_stage_mask = .{ .all_commands_bit = true },
            .src_access_mask = .{ .memory_write_bit = true },
            .dst_stage_mask = .{ .all_commands_bit = true },
            .dst_access_mask = .{ .memory_write_bit = true, .memory_read_bit = true },
            .old_layout = old_layout,
            .new_layout = new_layout,
            .src_queue_family_index = 0,
            .dst_queue_family_index = 0,
            .image = image,
            .subresource_range = .{
                .aspect_mask = switch (new_layout) {
                    vk.ImageLayout.depth_stencil_attachment_optimal => .{ .depth_bit = true },
                    else => .{ .color_bit = true },
                },
                .base_mip_level = 0,
                .level_count = vk.REMAINING_MIP_LEVELS,
                .base_array_layer = 0,
                .layer_count = vk.REMAINING_ARRAY_LAYERS,
            },
        };

        const dep_info = vk.DependencyInfo{
            .image_memory_barrier_count = 1,
            .p_image_memory_barriers = @ptrCast(&img_barrier),
        };

        self.device.cmdPipelineBarrier2(cmd, &dep_info);
    }
};
