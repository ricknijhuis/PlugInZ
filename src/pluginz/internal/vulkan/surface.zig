const std = @import("std");

const glfw = @import("glfw");
const vk = @import("vulkan");

const ResourceBufferUnmanaged = @import("../../resource_buffer.zig").ResourceBufferUnmanaged;
const WindowResource = @import("../platform/window.zig").WindowResource;
const Renderer = @import("../renderer.zig").Renderer;

pub const SurfaceConfig = struct {
    frames_in_flight: u32 = 2,
};

pub const SurfaceResourceBuffer = ResourceBufferUnmanaged(SurfaceResource);
pub const SurfaceResourceHandle = SurfaceResourceBuffer.Handle;
pub const SurfaceResource = struct {
    surface: vk.SurfaceKHR,
    swapchain: vk.SwapchainKHR,
    extend: vk.Extent2D,
    command_pool: vk.CommandPool,
    images: []vk.Image,
    image_views: []vk.ImageView,
    command_buffers: []vk.CommandBuffer,
    swapchain_semaphores: []vk.Semaphore,
    render_semaphores: []vk.Semaphore,
    fences: []vk.Fence,

    frames_in_flight: u32,
    current_frame: u32,

    is_resized: bool,
    is_minimized: bool,

    pub fn init(
        self: *SurfaceResource,
        renderer: *Renderer,
        allocator: std.mem.Allocator,
        window: *WindowResource,
        config: SurfaceConfig,
    ) !void {
        const instance = renderer.instance;
        const device = renderer.device;
        std.debug.assert(instance.handle != .null_handle);
        std.debug.assert(device.handle != .null_handle);

        self.surface = undefined;
        self.swapchain = .null_handle;
        self.extend = undefined;
        self.command_pool = undefined;
        self.images = &[_]vk.Image{};
        self.image_views = &[_]vk.ImageView{};
        self.command_buffers = &[_]vk.CommandBuffer{};
        self.swapchain_semaphores = &[_]vk.Semaphore{};
        self.render_semaphores = &[_]vk.Semaphore{};
        self.fences = &[_]vk.Fence{};
        self.is_resized = false;
        self.is_minimized = false;
        self.frames_in_flight = config.frames_in_flight;
        self.current_frame = 0;

        if (glfwCreateWindowSurface(
            instance.handle,
            window.handle,
            null,
            &self.surface,
        ) != .success) {
            return error.SurfaceInitFailed;
        }
        errdefer instance.destroySurfaceKHR(self.surface, null);

        try self.createSwapChain(renderer, allocator, window);
        errdefer self.destroySwapchain(renderer, allocator);

        try self.createImageViews(renderer, allocator);
        errdefer allocator.free(self.image_views);

        try self.createSyncObjects(renderer, allocator);
        errdefer self.destroySyncObjects(renderer, allocator);

        try self.createCommandPool(renderer);
        errdefer device.destroyCommandPool(self.command_pool, null);

        try self.createCommandBuffers(renderer, allocator);
        errdefer allocator.free(self.command_buffers);
    }

    pub fn deinit(self: *SurfaceResource, renderer: *Renderer, allocator: std.mem.Allocator) void {
        const instance = renderer.instance;
        const device = renderer.device;

        // if exception occurs it means something else is seriously wrong
        device.deviceWaitIdle() catch unreachable;

        std.debug.assert(renderer.instance.handle != .null_handle);
        std.debug.assert(renderer.device.handle != .null_handle);
        std.debug.assert(self.images.len > 0);
        std.debug.assert(self.image_views.len > 0);
        std.debug.assert(self.command_buffers.len > 0);
        std.debug.assert(self.render_semaphores.len > 0);
        std.debug.assert(self.swapchain_semaphores.len > 0);
        std.debug.assert(self.fences.len > 0);

        self.destroySyncObjects(renderer, allocator);

        device.destroyCommandPool(self.command_pool, null);

        allocator.free(self.command_buffers);

        self.destroyImageViews(renderer, allocator);

        self.destroySwapchain(renderer, allocator);

        instance.destroySurfaceKHR(self.surface, null);
    }

    fn createSwapChain(self: *SurfaceResource, renderer: *Renderer, allocator: std.mem.Allocator, window: *WindowResource) !void {
        const instance = renderer.instance;
        const physical_device = renderer.physical_devices[renderer.physical_device].device;
        const device = renderer.device;

        std.debug.assert(device.handle != .null_handle);

        const capabilities = try instance.getPhysicalDeviceSurfaceCapabilitiesKHR(
            physical_device,
            self.surface,
        );
        const formats = try instance.getPhysicalDeviceSurfaceFormatsAllocKHR(
            physical_device,
            self.surface,
            allocator,
        );
        defer allocator.free(formats);

        var picked_format = formats[0];
        for (formats) |format| {
            if (format.format == renderer.format and format.color_space == vk.ColorSpaceKHR.srgb_nonlinear_khr) {
                picked_format = format;
                break;
            }
        }

        const present_modes = try instance.getPhysicalDeviceSurfacePresentModesAllocKHR(
            physical_device,
            self.surface,
            allocator,
        );
        defer allocator.free(present_modes);

        var picked_present_mode = vk.PresentModeKHR.fifo_khr;
        for (present_modes) |mode| {
            if (mode == vk.PresentModeKHR.mailbox_khr) {
                picked_present_mode = mode;
            }
        }

        var extend: vk.Extent2D = undefined;

        if (capabilities.current_extent.width != std.math.maxInt(u32)) {
            extend = capabilities.current_extent;
        } else {
            var width: i32 = 0;
            var height: i32 = 0;
            glfw.getFramebufferSize(window.handle, &width, &height);

            extend = .{
                .width = @intCast(width),
                .height = @intCast(height),
            };

            extend.width = std.math.clamp(extend.width, capabilities.min_image_extent.width, capabilities.max_image_extent.width);
            extend.height = std.math.clamp(extend.height, capabilities.min_image_extent.height, capabilities.max_image_extent.height);
        }

        var image_count = capabilities.min_image_count + 1;

        if (capabilities.max_image_count > 0 and image_count > capabilities.max_image_count) {
            image_count = capabilities.max_image_count;
        }

        var create_info = vk.SwapchainCreateInfoKHR{
            .surface = self.surface,
            .min_image_count = image_count,
            .image_format = picked_format.format,
            .image_color_space = picked_format.color_space,
            .image_extent = extend,
            .image_array_layers = 1,
            .image_usage = vk.ImageUsageFlags{ .color_attachment_bit = true, .transfer_dst_bit = true },
            .pre_transform = capabilities.current_transform,
            .composite_alpha = vk.CompositeAlphaFlagsKHR{ .opaque_bit_khr = true },
            .present_mode = picked_present_mode,
            .clipped = vk.TRUE,
            .image_sharing_mode = undefined,
            .old_swapchain = self.swapchain,
        };

        const indices = [_]u32{ renderer.device_graphics_queue_family_index, renderer.device_present_queue_family_index };
        if (renderer.device_graphics_queue_family_index != renderer.device_present_queue_family_index) {
            create_info.image_sharing_mode = vk.SharingMode.concurrent;
            create_info.queue_family_index_count = 2;
            create_info.p_queue_family_indices = indices[0..].ptr;
        } else {
            create_info.image_sharing_mode = vk.SharingMode.exclusive;
            create_info.queue_family_index_count = 1;
            create_info.p_queue_family_indices = indices[0..1].ptr;
        }

        self.swapchain = try device.createSwapchainKHR(&create_info, null);
        self.images = try device.getSwapchainImagesAllocKHR(self.swapchain, allocator);
        self.extend = extend;
    }

    fn createImageViews(self: *SurfaceResource, renderer: *Renderer, allocator: std.mem.Allocator) !void {
        const device = renderer.device;

        std.debug.assert(device.handle != .null_handle);

        self.image_views = try allocator.alloc(vk.ImageView, self.images.len);

        for (self.images, 0..) |image, i| {
            var create_info = vk.ImageViewCreateInfo{
                .image = image,
                .view_type = vk.ImageViewType.@"2d",
                .format = renderer.format,
                .components = .{
                    .r = vk.ComponentSwizzle.identity,
                    .g = vk.ComponentSwizzle.identity,
                    .b = vk.ComponentSwizzle.identity,
                    .a = vk.ComponentSwizzle.identity,
                },
                .subresource_range = .{
                    .aspect_mask = vk.ImageAspectFlags{ .color_bit = true },
                    .base_mip_level = 0,
                    .level_count = 1,
                    .base_array_layer = 0,
                    .layer_count = 1,
                },
            };

            self.image_views[i] = try device.createImageView(&create_info, null);
        }
    }

    fn createCommandPool(self: *SurfaceResource, renderer: *Renderer) !void {
        const device = renderer.device;

        std.debug.assert(device.handle != .null_handle);

        const create_info = vk.CommandPoolCreateInfo{
            .flags = .{ .reset_command_buffer_bit = true },
            .queue_family_index = renderer.device_graphics_queue_family_index,
        };

        self.command_pool = try device.createCommandPool(&create_info, null);
    }

    fn createCommandBuffers(self: *SurfaceResource, renderer: *Renderer, allocator: std.mem.Allocator) !void {
        const device = renderer.device;

        std.debug.assert(device.handle != .null_handle);

        self.command_buffers = try allocator.alloc(vk.CommandBuffer, self.frames_in_flight);

        const alloc_info = vk.CommandBufferAllocateInfo{
            .command_pool = self.command_pool,
            .level = vk.CommandBufferLevel.primary,
            .command_buffer_count = @intCast(self.command_buffers.len),
        };

        try device.allocateCommandBuffers(&alloc_info, self.command_buffers.ptr);
    }

    fn createSyncObjects(self: *SurfaceResource, renderer: *Renderer, allocator: std.mem.Allocator) !void {
        const device = renderer.device;

        std.debug.assert(device.handle != .null_handle);

        self.swapchain_semaphores = try allocator.alloc(vk.Semaphore, self.frames_in_flight);
        self.render_semaphores = try allocator.alloc(vk.Semaphore, self.frames_in_flight);
        self.fences = try allocator.alloc(vk.Fence, self.frames_in_flight);

        const fence_create_info = vk.FenceCreateInfo{
            .flags = .{ .signaled_bit = true },
        };

        const semaphore_create_info = vk.SemaphoreCreateInfo{};

        for (self.swapchain_semaphores, self.render_semaphores, self.fences) |
            *swapchain_semaphore,
            *render_semaphore,
            *fence,
        | {
            swapchain_semaphore.* = try device.createSemaphore(&semaphore_create_info, null);
            render_semaphore.* = try device.createSemaphore(&semaphore_create_info, null);
            fence.* = try device.createFence(&fence_create_info, null);
        }
    }

    fn destroySyncObjects(self: *SurfaceResource, renderer: *Renderer, allocator: std.mem.Allocator) void {
        const device = renderer.device;

        for (self.render_semaphores, self.swapchain_semaphores, self.fences) |
            render_semaphore,
            swapchain_semaphore,
            fence,
        | {
            device.destroySemaphore(render_semaphore, null);
            device.destroySemaphore(swapchain_semaphore, null);
            device.destroyFence(fence, null);
        }

        allocator.free(self.render_semaphores);
        allocator.free(self.swapchain_semaphores);
        allocator.free(self.fences);
    }

    fn destroySwapchain(self: *SurfaceResource, renderer: *Renderer, allocator: std.mem.Allocator) void {
        const device = renderer.device;

        device.destroySwapchainKHR(self.swapchain, null);
        allocator.free(self.images);
    }

    fn destroyImageViews(self: *SurfaceResource, renderer: *Renderer, allocator: std.mem.Allocator) void {
        const device = renderer.device;

        for (self.image_views) |image_view| {
            device.destroyImageView(image_view, null);
        }

        allocator.free(self.image_views);
    }
};

extern fn glfwCreateWindowSurface(instance: vk.Instance, window: *glfw.Window, allocation_callbacks: ?*const vk.AllocationCallbacks, surface: *vk.SurfaceKHR) vk.Result;
