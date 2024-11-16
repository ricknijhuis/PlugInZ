const std = @import("std");
const vk = @import("vulkan");
const c = @import("c.zig");

const core = @import("core.zig");
const VulkanPhysicalDevice = core.VulkanPhysicalDevice;
const DeviceRequirements = core.DeviceRequirements;
const DeviceQueueFamilyIndices = core.DeviceQueueFamilyIndices;
const VulkanContext = core.VulkanContext;
const DeviceDispatch = core.DeviceDispatch;
const Device = core.Device;

pub const VulkanLogicalDevice = struct {
    ctx: *const VulkanContext,
    device: Device,
    graphics_queue: vk.Queue,
    present_queue: vk.Queue,

    pub fn init(
        context: *const VulkanContext,
        physical_device: *const VulkanPhysicalDevice,
        requirements: DeviceRequirements,
    ) !*VulkanLogicalDevice {
        const self = try context.allocator.create(VulkanLogicalDevice);
        errdefer context.allocator.destroy(self);

        self.ctx = context;

        var queues: ?DeviceQueueFamilyIndices = null;
        var queue_create_info_count: u32 = 0;
        const queue_create_info = [2]vk.DeviceQueueCreateInfo{ .{}, .{} };

        if (requirements.surface) |surface| {
            const priority = [_]f32{1};
            queues = physical_device.getQueueFamilies(surface);
            if (queues) |families| {
                queue_create_info[0].queue_family_index = families.graphics_family;
                queue_create_info[0].queue_count = 1;
                queue_create_info[0].p_queue_priorities = &priority;

                queue_create_info[0].queue_family_index = families.present_family;
                queue_create_info[0].queue_count = 1;
                queue_create_info[0].p_queue_priorities = &priority;

                queue_create_info_count = if (families.graphics_family == families.present_family)
                    1
                else
                    2;
            }
        }

        const device = try context.instance.createDevice(physical_device, &.{
            .queue_create_info_count = queue_create_info_count,
            .p_queue_create_infos = &queue_create_info,
            .enabled_extension_count = requirements.extensions.len,
            .pp_enabled_extension_names = @ptrCast(requirements.extensions.ptr),
        }, null);
        const device_dispatch = try context.allocator.create(DeviceDispatch);
        errdefer context.allocator.destroy(device_dispatch);

        device_dispatch.* = try DeviceDispatch.load(device, context.instance.wrapper.dispatch.vkGetDeviceProcAddr);
        self.device = Device.init(device, device_dispatch);

        if (queues) |families| {
            self.graphics_queue = self.device.getDeviceQueue(families.graphics_queue_family, 0);
            self.present_queue = self.device.getDeviceQueue(families.present_queue_family, 0);
        }
    }

    pub fn deinit(self: VulkanLogicalDevice) void {
        self.device.destroyDevice(null);
        self.ctx.allocator.destroy(self.device.wrapper);
    }
};
