const std = @import("std");

const vk = @import("vulkan");

const InstanceProxy = @import("wrapper.zig").InstanceProxy;

pub const PhysicalDeviceQueueFamilyIndices = struct {
    graphics: ?u32,
    present: ?u32,
    compute: ?u32,
    transfer: ?u32,
};

pub const PhysicalDevice = struct {
    device: vk.PhysicalDevice,
    properties: vk.PhysicalDeviceProperties,
    mem_properties: vk.PhysicalDeviceMemoryProperties,
    features: vk.PhysicalDeviceFeatures,
    extensions: []vk.ExtensionProperties,
    queue_families: []vk.QueueFamilyProperties,

    pub fn init(self: *PhysicalDevice, allocator: std.mem.Allocator, instance: InstanceProxy, physical_device: vk.PhysicalDevice) !void {
        self.device = physical_device;
        self.properties = instance.getPhysicalDeviceProperties(physical_device);
        self.mem_properties = instance.getPhysicalDeviceMemoryProperties(physical_device);
        self.features = instance.getPhysicalDeviceFeatures(physical_device);
        self.extensions = try instance.enumerateDeviceExtensionPropertiesAlloc(
            physical_device,
            null,
            allocator,
        );

        errdefer allocator.free(self.extensions);

        self.queue_families = try instance.getPhysicalDeviceQueueFamilyPropertiesAlloc(
            physical_device,
            allocator,
        );

        errdefer allocator.free(self.queue_families);
    }

    pub fn deinit(self: *PhysicalDevice, allocator: std.mem.Allocator) void {
        allocator.free(self.queue_families);
        allocator.free(self.extensions);
    }

    pub fn supportsExtensions(
        self: *const PhysicalDevice,
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

    pub fn supportsSurface(self: *const PhysicalDevice, instance: InstanceProxy, surface: vk.SurfaceKHR) !bool {
        std.debug.assert(instance.handle != .null_handle);
        std.debug.assert(self.device != .null_handle);

        var format_count: u32 = undefined;
        _ = try instance.getPhysicalDeviceSurfaceFormatsKHR(self.device, surface, &format_count, null);

        var present_mode_count: u32 = undefined;
        _ = try instance.getPhysicalDeviceSurfacePresentModesKHR(self.device, surface, &present_mode_count, null);

        return format_count > 0 and present_mode_count > 0;
    }

    pub fn getQueueFamilies(self: *const PhysicalDevice, instance: InstanceProxy, surface: vk.SurfaceKHR) !PhysicalDeviceQueueFamilyIndices {
        std.debug.assert(instance.handle != .null_handle);

        var families = PhysicalDeviceQueueFamilyIndices{
            .graphics = null,
            .present = null,
            .compute = null,
            .transfer = null,
        };

        for (self.queue_families, 0..) |properties, i| {
            const family: u32 = @intCast(i);

            if (families.graphics == null and properties.queue_flags.graphics_bit) {
                families.graphics = family;
            }

            if (families.present == null and (try instance.getPhysicalDeviceSurfaceSupportKHR(
                self.device,
                family,
                surface,
            )) == vk.TRUE) {
                families.present = family;
            }

            if (properties.queue_flags.compute_bit) {
                families.compute = family;
            }

            if (properties.queue_flags.transfer_bit) {
                families.transfer = family;
            }
        }

        return families;
    }

    pub fn isBetterThan(self: *PhysicalDevice, other: *PhysicalDevice) bool {
        if (self.properties.device_type == vk.PhysicalDeviceType.discrete_gpu and other.properties.device_type != vk.PhysicalDeviceType.discrete_gpu)
            return true;

        if (self.properties.device_type == vk.PhysicalDeviceType.integrated_gpu and other.properties.device_type != vk.PhysicalDeviceType.integrated_gpu)
            return true;

        // check memory size
        var total_device_local: vk.DeviceSize = 0;
        for (self.mem_properties.memory_heaps) |heap| {
            if (heap.flags.device_local_bit) {
                total_device_local += heap.size;
            }
        }

        var other_total_device_local: vk.DeviceSize = 0;
        for (other.mem_properties.memory_heaps) |heap| {
            if (heap.flags.device_local_bit) {
                other_total_device_local += heap.size;
            }
        }

        if (total_device_local > other_total_device_local)
            return true;

        return false;
    }
};
