const std = @import("std");
const vk = @import("vulkan");
const c = @import("c.zig");
const core = @import("core.zig");

const Window = @import("pluginz.platform").Window;
const VulkanContext = core.VulkanContext;
const VulkanLogicalDevice = core.VulkanLogicalDevice;
const DeviceRequirements = core.DeviceRequirements;

const SwapImage = struct {
    image: vk.Image,
    view: vk.ImageView,
    image_acquired: vk.Semaphore,
    render_finished: vk.Semaphore,
    frame_fence: vk.Fence,
};

pub const VulkanSurface = struct {
    ctx: *const VulkanContext,
    device: *const VulkanLogicalDevice,

    surface: vk.SurfaceKHR,
    surface_format: vk.SurfaceFormatKHR,
    present_mode: vk.PresentModeKHR,
    extent: vk.Extent2D,
    handle: vk.SwapchainKHR,

    swap_images: []SwapImage,
    image_index: u32,
    next_image_acquired: vk.Semaphore,

    pub fn init(context: *const VulkanContext, window: Window) !*VulkanSurface {
        const self = try context.allocator.create(VulkanSurface);

        self.ctx = context;
        self.surface = try self.createSurface(@ptrCast(window.handle));
        self.device = try self.pickDevice();
    }

    pub fn deinit(self: VulkanSurface) void {
        _ = self; // autofix

    }

    fn createSurface(self: *VulkanSurface, window: *c.GLFWwindow) !vk.SurfaceKHR {
        var surface: vk.SurfaceKHR = undefined;
        if (c.glfwCreateWindowSurface(
            self.ctx.instance.handle,
            window,
            null,
            &surface,
        ) != .success) {
            return error.SurfaceInitFailed;
        }
        return surface;
    }

    pub fn pickDevice(self: VulkanSurface) !*const VulkanLogicalDevice {
        const extensions = [_][*:0]const u8{vk.extensions.khr_swapchain.name};
        const requirements: DeviceRequirements = .{
            .surface = self.surface,
            .extensions = &extensions,
        };
        for (self.ctx.devices) |*device| {
            if (try device.meetsRequirements(requirements)) {
                self.device = try VulkanLogicalDevice.init(self.ctx, device, requirements);
            }
        }

        return error.NoValidDeviceFound;
    }
};
