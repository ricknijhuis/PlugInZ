const std = @import("std");
const vk = @import("vulkan");
const core = @import("core.zig");

const VulkanContext = core.VulkanContext;
const VulkanPhysicalDevice = core.VulkanPhysicalDevice;

pub const VulkanPhysicalDeviceCollection = struct {
    allocator: std.mem.Allocator,
    devices: []VulkanPhysicalDevice,

    pub fn init(allocator: std.mem.Allocator, context: *const VulkanContext) !VulkanPhysicalDeviceCollection {
        var self = VulkanPhysicalDeviceCollection{
            .allocator = allocator,
            .devices = undefined,
        };

        const physical_devices = try context.instance.enumeratePhysicalDevicesAlloc(allocator);
        defer self.allocator.free(physical_devices);

        self.devices = try self.allocator.alloc(VulkanPhysicalDevice, physical_devices.len);
        errdefer self.allocator.free(self.devices);

        for (self.devices, 0..) |*device, i| {
            const physical_device = physical_devices[i];
            try device.init(context, physical_device);
        }

        errdefer {
            for (self.devices) |device| {
                device.deinit();
            }
        }

        std.mem.sort(VulkanPhysicalDevice, self.devices, {}, sortDeviceLessThan);

        return self;
    }

    pub fn deinit(self: *const VulkanPhysicalDeviceCollection) void {
        for (self.devices) |device| {
            device.deinit();
        }

        self.allocator.free(self.devices);
    }

    // orders by gpu type and memory size (general indicative of gpu performance)
    fn sortDeviceLessThan(context: void, lhs: VulkanPhysicalDevice, rhs: VulkanPhysicalDevice) bool {
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
};
