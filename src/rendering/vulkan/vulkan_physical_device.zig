const std = @import("std");
const vk = @import("vulkan");
const c = @import("c.zig");

const core = @import("core.zig");

const VulkanContext = core.VulkanContext;
const DeviceDispatch = core.DeviceDispatch;

pub const DeviceRequirements = struct {
    extensions: []const [*]const u8,
    surface: ?vk.SurfaceKHR,
};

pub const DeviceQueueFamilyIndices = struct {
    graphics_family: u32,
    present_family: u32,
};

pub const VulkanPhysicalDevice = struct {
    ctx: *const VulkanContext,
    physical_device: vk.PhysicalDevice,
    physical_device_properties: vk.PhysicalDeviceProperties,
    physical_device_mem_properties: vk.PhysicalDeviceMemoryProperties,
    physical_device_features: vk.PhysicalDeviceFeatures,
    physical_device_extensions: []vk.ExtensionProperties,
    physical_device_queue_families: []vk.QueueFamilyProperties,

    pub fn init(self: *VulkanPhysicalDevice, ctx: *const VulkanContext, physical_device: vk.PhysicalDevice) !void {
        self.ctx = ctx;
        self.physical_device = physical_device;
        self.physical_device_properties = ctx.instance.getPhysicalDeviceProperties(physical_device);
        self.physical_device_mem_properties = ctx.instance.getPhysicalDeviceMemoryProperties(physical_device);
        self.physical_device_features = ctx.instance.getPhysicalDeviceFeatures(physical_device);
        self.physical_device_queue_families = try ctx.instance.getPhysicalDeviceQueueFamilyPropertiesAlloc(
            physical_device,
            ctx.allocator,
        );
        self.physical_device_extensions = try ctx.instance.enumerateDeviceExtensionPropertiesAlloc(
            physical_device,
            null,
            ctx.allocator,
        );
    }

    pub fn deinit(self: VulkanPhysicalDevice) void {
        self.allocator.free(self.physical_device_extensions);
        self.allocator.free(self.physical_device_queue_families);
    }

    pub fn meetsRequirements(self: VulkanPhysicalDevice, requirements: DeviceRequirements) !bool {
        if (requirements.extensions.len > 0) {
            if (!self.checkExtensionSupport(requirements.extensions))
                return false;
        }

        if (requirements.surface) |surface| {
            if (!try self.checkSurfaceSupport(surface))
                return false;
            if (!try self.checkQueueSupport(surface))
                return false;
        }

        return true;
    }

    fn checkExtensionSupport(
        self: VulkanPhysicalDevice,
        extensions: []const [*c]const u8,
    ) bool {
        for (extensions) |required_extension| {
            for (self.physical_device_extensions) |extension| {
                if (std.mem.eql(u8, std.mem.span(required_extension), std.mem.sliceTo(&extension.extension_name, 0))) {
                    break;
                }
            } else {
                return false;
            }
        }

        return true;
    }

    fn checkSurfaceSupport(self: VulkanPhysicalDevice, surface: vk.SurfaceKHR) !bool {
        var format_count: u32 = undefined;
        _ = try self.ctx.instance.getPhysicalDeviceSurfaceFormatsKHR(self.physical_device, surface, &format_count, null);

        var present_mode_count: u32 = undefined;
        _ = try self.ctx.instance.getPhysicalDeviceSurfacePresentModesKHR(self.physical_device, surface, &present_mode_count, null);

        return format_count > 0 and present_mode_count > 0;
    }

    fn checkQueueSupport(self: VulkanPhysicalDevice, surface: vk.SurfaceKHR) !bool {
        if (try self.getQueueFamilies(surface) != null) {
            return true;
        }

        return false;
    }

    fn getQueueFamilies(self: VulkanPhysicalDevice, surface: vk.SurfaceKHR) !?DeviceQueueFamilyIndices {
        var graphics_family: ?u32 = null;
        var present_family: ?u32 = null;

        for (self.physical_device_queue_families, 0..) |properties, i| {
            const family: u32 = @intCast(i);

            if (graphics_family == null and properties.queue_flags.graphics_bit) {
                graphics_family = family;
            }

            if (present_family == null and (try self.ctx.instance.getPhysicalDeviceSurfaceSupportKHR(
                self.physical_device,
                family,
                surface,
            )) == vk.TRUE) {
                present_family = family;
            }
        }

        if (graphics_family != null and present_family != null) {
            return .{
                .graphics_family = graphics_family.?,
                .present_family = present_family.?,
            };
        }

        return null;
    }
};
