const std = @import("std");
const vk = @import("vulkan");
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
    device: vk.PhysicalDevice,
    properties: vk.PhysicalDeviceProperties,
    mem_properties: vk.PhysicalDeviceMemoryProperties,
    features: vk.PhysicalDeviceFeatures,
    extensions: []vk.ExtensionProperties,
    queue_families: []vk.QueueFamilyProperties,

    pub fn init(self: *VulkanPhysicalDevice, ctx: *const VulkanContext, physical_device: vk.PhysicalDevice) !void {
        self.ctx = ctx;
        self.device = physical_device;
        self.properties = ctx.instance.getPhysicalDeviceProperties(physical_device);
        self.mem_properties = ctx.instance.getPhysicalDeviceMemoryProperties(physical_device);
        self.features = ctx.instance.getPhysicalDeviceFeatures(physical_device);
        self.queue_families = try ctx.instance.getPhysicalDeviceQueueFamilyPropertiesAlloc(
            physical_device,
            ctx.allocator,
        );
        self.extensions = try ctx.instance.enumerateDeviceExtensionPropertiesAlloc(
            physical_device,
            null,
            ctx.allocator,
        );
    }

    pub fn deinit(self: VulkanPhysicalDevice) void {
        self.ctx.allocator.free(self.extensions);
        self.ctx.allocator.free(self.queue_families);
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
            for (self.extensions) |extension| {
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
        _ = try self.ctx.instance.getPhysicalDeviceSurfaceFormatsKHR(self.device, surface, &format_count, null);

        var present_mode_count: u32 = undefined;
        _ = try self.ctx.instance.getPhysicalDeviceSurfacePresentModesKHR(self.device, surface, &present_mode_count, null);

        return format_count > 0 and present_mode_count > 0;
    }

    fn checkQueueSupport(self: VulkanPhysicalDevice, surface: vk.SurfaceKHR) !bool {
        if (try self.getQueueFamilies(surface) != null) {
            return true;
        }

        return false;
    }

    // orders by gpu type and memory size (general indicative of gpu performance)
    pub fn sortDeviceLessThan(context: void, lhs: VulkanPhysicalDevice, rhs: VulkanPhysicalDevice) bool {
        _ = context; // autofix
        // prefer discrete gpu
        if (lhs.properties.device_type == vk.PhysicalDeviceType.discrete_gpu and rhs.properties.device_type != vk.PhysicalDeviceType.discrete_gpu)
            return false;

        // if not discrete prefer integrated
        if (lhs.properties.device_type == vk.PhysicalDeviceType.integrated_gpu and rhs.properties.device_type != vk.PhysicalDeviceType.integrated_gpu)
            return false;

        // check memory size
        var lhs_total_device_local: vk.DeviceSize = 0;
        for (lhs.mem_properties.memory_heaps) |heap| {
            if (heap.flags.device_local_bit) {
                lhs_total_device_local += heap.size;
            }
        }

        var rhs_total_device_local: vk.DeviceSize = 0;
        for (rhs.mem_properties.memory_heaps) |heap| {
            if (heap.flags.device_local_bit) {
                rhs_total_device_local += heap.size;
            }
        }

        if (lhs_total_device_local > rhs_total_device_local)
            return false;

        return true;
    }

    pub fn getQueueFamilies(self: VulkanPhysicalDevice, surface: vk.SurfaceKHR) !?DeviceQueueFamilyIndices {
        var graphics_family: ?u32 = null;
        var present_family: ?u32 = null;

        for (self.queue_families, 0..) |properties, i| {
            const family: u32 = @intCast(i);

            if (graphics_family == null and properties.queue_flags.graphics_bit) {
                graphics_family = family;
            }

            if (present_family == null and (try self.ctx.instance.getPhysicalDeviceSurfaceSupportKHR(
                self.device,
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
