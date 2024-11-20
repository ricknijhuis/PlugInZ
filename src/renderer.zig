const std = @import("std");
const vk = @import("vulkan");
const glfw = @import("glfw");
const core = @import("vulkan/core.zig");

const Platform = @import("platform.zig").Platform;
const Window = @import("window.zig").Window;
const VulkanContext = core.VulkanContext;
const VulkanPhysicalDevice = core.VulkanPhysicalDevice;
const VulkanPhysicalDeviceCollection = core.VulkanPhysicalDeviceCollection;
const VulkanLogicalDevice = core.VulkanLogicalDevice;
const VulkanSurface = core.VulkanSurface;

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    context: VulkanContext,
    devices: VulkanPhysicalDeviceCollection,
    // For now only a single logical device is supported, this might cause trouble if you have multiple surfaces
    // of wich one is on a different monitor connected with another physical device.
    device: VulkanLogicalDevice,

    surfaces: []VulkanSurface,
    surfaces_capacity: u32,

    pub fn init(platform: *const Platform) !*Renderer {
        const self = try platform.allocator.create(Renderer);

        self.allocator = platform.allocator;
        self.context = try VulkanContext.init(platform);
        self.devices = try VulkanPhysicalDeviceCollection.init(platform.allocator, &self.context);
        self.device = try VulkanLogicalDevice.init(&self.context, &self.devices);
        const capacity: u32 = 0;
        self.surfaces = &[_]VulkanSurface{};
        self.surfaces_capacity = capacity;

        return self;
    }

    pub fn deinit(self: *Renderer) void {
        for (self.surfaces) |*surface| {
            surface.deinit();
        }

        self.device.deinit();
        self.devices.deinit();
        self.context.deinit();

        self.allocator.free(self.surfaces);
        self.surfaces_capacity = 0;

        self.allocator.destroy(self);
    }

    pub fn addWindow(self: *Renderer, window: *const Window) !void {
        if (self.surfaces.len == self.surfaces_capacity) {
            self.surfaces_capacity += 1;
            self.surfaces = try self.allocator.realloc(self.surfaces, self.surfaces_capacity);
        }

        self.surfaces[self.surfaces.len - 1] = try VulkanSurface.init(&self.context, &self.device, window);
    }
};
