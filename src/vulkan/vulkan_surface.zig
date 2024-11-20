const std = @import("std");
const vk = @import("vulkan");
const glfw = @import("glfw");
const core = @import("core.zig");

const Platform = @import("../platform.zig").Platform;
const Window = @import("../window.zig").Window;
const VulkanPhysicalDevice = core.VulkanPhysicalDevice;
const VulkanLogicalDevice = core.VulkanLogicalDevice;
const VulkanContext = core.VulkanContext;

pub const VulkanSurface = struct {
    context: *const VulkanContext,
    device: *const VulkanLogicalDevice,
    window: *const Window,
    surface: vk.SurfaceKHR,
    swapchain: vk.SwapchainKHR,
    images: []vk.Image,
    image_views: []vk.ImageView,
    format: vk.Format,
    extend: vk.Extent2D,

    pub fn init(context: *const VulkanContext, device: *const VulkanLogicalDevice, window: *const Window) !VulkanSurface {
        var self = VulkanSurface{
            .context = context,
            .device = device,
            .window = window,
            .surface = undefined,
            .swapchain = undefined,
            .images = undefined,
            .image_views = undefined,
            .format = undefined,
            .extend = undefined,
        };

        var surface: vk.SurfaceKHR = undefined;
        if (core.glfwCreateWindowSurface(self.context.instance.handle, window.handle, null, &surface) != .success)
            return error.SurfaceInitFailed;

        errdefer self.context.instance.destroySurfaceKHR(surface, null);

        if (try self.context.instance.getPhysicalDeviceSurfaceSupportKHR(device.physical_device.device, device.present_queue_family_index, surface) == vk.FALSE)
            return error.InvalidDeviceForSurface;

        try self.createSwapChain(surface);
        try self.createImageViews();

        return self;
    }

    pub fn deinit(self: *VulkanSurface) void {
        for (self.image_views) |image_view| {
            self.device.device.destroyImageView(image_view, null);
        }
        self.device.device.destroySwapchainKHR(self.swapchain, null);
        self.context.instance.destroySurfaceKHR(self.surface, null);

        self.context.allocator.free(self.image_views);
        self.context.allocator.free(self.images);
    }

    pub fn resize(self: *const VulkanSurface) !void {
        _ = self; // autofix
    }

    fn createSwapChain(self: *VulkanSurface, surface: vk.SurfaceKHR) !void {
        const capabilities = try self.context.instance.getPhysicalDeviceSurfaceCapabilitiesKHR(self.device.physical_device.device, surface);
        const formats = try self.context.instance.getPhysicalDeviceSurfaceFormatsAllocKHR(self.device.physical_device.device, surface, self.context.allocator);
        defer self.context.allocator.free(formats);

        var picked_format = formats[0];
        for (formats) |format| {
            if (format.format == vk.Format.b8g8r8a8_srgb and format.color_space == vk.ColorSpaceKHR.srgb_nonlinear_khr) {
                picked_format = format;
                break;
            }
        }

        const present_modes = try self.context.instance.getPhysicalDeviceSurfacePresentModesAllocKHR(self.device.physical_device.device, surface, self.context.allocator);
        defer self.context.allocator.free(present_modes);

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
            glfw.getFramebufferSize(self.window.handle, &width, &height);

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
            .surface = surface,
            .min_image_count = image_count,
            .image_format = picked_format.format,
            .image_color_space = picked_format.color_space,
            .image_extent = extend,
            .image_array_layers = 1,
            .image_usage = vk.ImageUsageFlags{ .color_attachment_bit = true },
            .pre_transform = capabilities.current_transform,
            .composite_alpha = vk.CompositeAlphaFlagsKHR{ .opaque_bit_khr = true },
            .present_mode = picked_present_mode,
            .clipped = vk.TRUE,
            .image_sharing_mode = undefined,
        };

        if (self.device.graphics_queue_family_index != self.device.present_queue_family_index) {
            const indices = [_]u32{ self.device.graphics_queue_family_index, self.device.present_queue_family_index };
            create_info.image_sharing_mode = vk.SharingMode.concurrent;
            create_info.queue_family_index_count = 2;
            create_info.p_queue_family_indices = indices[0..].ptr;
        } else {
            create_info.image_sharing_mode = vk.SharingMode.exclusive;
            create_info.queue_family_index_count = 0;
            create_info.p_queue_family_indices = null;
        }

        self.swapchain = try self.device.device.createSwapchainKHR(&create_info, null);
        self.images = try self.device.device.getSwapchainImagesAllocKHR(self.swapchain, self.context.allocator);
        self.format = picked_format.format;
        self.extend = extend;
    }

    fn createImageViews(self: *VulkanSurface) !void {
        self.image_views = try self.context.allocator.alloc(vk.ImageView, self.images.len);

        std.log.info("{}, {}", .{ self.image_views.len, self.images.len });

        for (self.images, 0..) |image, i| {
            var create_info = vk.ImageViewCreateInfo{
                .image = image,
                .view_type = vk.ImageViewType.@"2d",
                .format = self.format,
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

            self.image_views[i] = try self.device.device.createImageView(&create_info, null);
        }
    }

    fn createFrameBuffers(self: *VulkanSurface) !void {
        _ = self; // autofix

    }
};
