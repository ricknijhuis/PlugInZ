const std = @import("std");
const builtin = @import("builtin");

const glfw = @import("glfw");
const vk = @import("vulkan");

const Renderer = @import("../renderer.zig").Renderer;
const DeviceDispatch = @import("wrapper.zig").DeviceDispatch;
const DeviceProxy = @import("wrapper.zig").DeviceProxy;
const InstanceProxy = @import("wrapper.zig").InstanceProxy;
const PhysicalDevice = @import("physical_device.zig").PhysicalDevice;
const PhysicalDeviceQueueFamilyIndices = @import("physical_device.zig").PhysicalDeviceQueueFamilyIndices;

const PhysicalDeviceQueueRequirements = packed struct {
    graphics: bool,
    present: bool,
    compute: bool,
    transfer: bool,
};
const PhysicalDeviceRequirements = struct {
    surface: vk.SurfaceKHR,
    extensions: []const [*:0]const u8,
    queues: PhysicalDeviceQueueRequirements,
};

pub const LogicalDevice = struct {
    pub fn init(self: *Renderer, allocator: std.mem.Allocator) !void {
        std.debug.assert(self.instance.handle != .null_handle);
        std.debug.assert(self.physical_devices.len > 0);

        // Create dummy window for getting a surface so we can create a device beforehand
        glfw.defaultWindowHints();
        glfw.windowHint(glfw.WindowHint.client_api, 0);
        glfw.windowHint(glfw.WindowHint.visible, 0);
        glfw.windowHint(glfw.WindowHint.focused, 0);
        glfw.windowHint(glfw.WindowHint.focus_on_show, 0);

        const handle = glfw.createWindow(1, 1, "", null, null) orelse {
            try glfw.convertToError(glfw.getError(null));
            return error.FailedToInitializeWindow;
        };

        defer glfw.destroyWindow(handle);
        defer glfw.defaultWindowHints();

        var surface: vk.SurfaceKHR = undefined;
        if (glfwCreateWindowSurface(self.instance.handle, handle, null, &surface) != .success) {
            return error.SurfaceInitFailed;
        }
        defer self.instance.destroySurfaceKHR(surface, null);

        const extensions = [_][*:0]const u8{
            // Required for creating swapchains and rendering to screen
            vk.extensions.khr_swapchain.name,
            // Required for enabling dynamic rendering features
            vk.extensions.khr_dynamic_rendering.name,
        };

        const device_requirements = PhysicalDeviceRequirements{
            .surface = surface,
            .extensions = extensions[0..],
            .queues = .{
                .graphics = true,
                .present = true,
                .compute = false,
                .transfer = false,
            },
        };
        var physical_device_queue_families: PhysicalDeviceQueueFamilyIndices = undefined;
        const physical_device_index = try pickPhysicalDevice(self, &device_requirements, &physical_device_queue_families);
        const physical_device = &self.physical_devices[physical_device_index];

        var queue_create_infos = [_]vk.DeviceQueueCreateInfo{undefined} ** 4;
        const queue_create_infos_length = try getQueueCreateInfos(physical_device_queue_families, &queue_create_infos);

        self.device_graphics_queue_family_index = queue_create_infos[0].queue_family_index;

        if (queue_create_infos_length > 1) {
            self.device_present_queue_family_index = queue_create_infos[1].queue_family_index;
        }

        self.physical_device = physical_device_index;

        self.device_graphics_queue_family_index = physical_device_queue_families.graphics orelse
            return error.GraphicsQueueNotAvailable;
        self.device_present_queue_family_index = physical_device_queue_families.present orelse
            return error.PresentQueueNotAvailable;

        const features1_3 = vk.PhysicalDeviceVulkan13Features{
            .synchronization_2 = vk.TRUE,
            .dynamic_rendering = vk.TRUE,
        };

        const device_create_info = vk.DeviceCreateInfo{
            .p_next = &features1_3,
            .queue_create_info_count = queue_create_infos_length,
            .p_queue_create_infos = &queue_create_infos,
            .enabled_extension_count = @intCast(extensions.len),
            .pp_enabled_extension_names = @ptrCast(&extensions[0]),
        };

        const device = try self.instance.createDevice(physical_device.device, &device_create_info, null);

        const device_dispatch = try allocator.create(DeviceDispatch);
        errdefer allocator.destroy(device_dispatch);

        device_dispatch.* = try DeviceDispatch.load(device, self.instance.wrapper.dispatch.vkGetDeviceProcAddr);

        self.device = DeviceProxy.init(device, device_dispatch);

        self.device_graphics_queue = self.device.getDeviceQueue(self.device_graphics_queue_family_index, 0);

        if (self.device_graphics_queue_family_index != self.device_present_queue_family_index)
            self.device_present_queue = self.device.getDeviceQueue(self.device_present_queue_family_index, 0);
    }

    pub fn deinit(self: *Renderer, allocator: std.mem.Allocator) void {
        self.device.destroyDevice(null);
        allocator.destroy(self.device.wrapper);
    }

    fn pickPhysicalDevice(
        self: *Renderer,
        requirements: *const PhysicalDeviceRequirements,
        result_queues: *PhysicalDeviceQueueFamilyIndices,
    ) !u32 {
        var picked_device: ?*PhysicalDevice = null;
        var picked_device_index: usize = undefined;

        for (self.physical_devices, 0..) |*device, i| {
            if (!device.supportsExtensions(requirements.extensions))
                continue;

            if (!try device.supportsSurface(self.instance, requirements.surface))
                continue;

            if (picked_device) |prev_device| {
                if (device.isBetterThan(prev_device)) {
                    result_queues.* = try device.getQueueFamilies(self.instance, requirements.surface);
                    picked_device_index = i;
                    picked_device = device;
                }
            } else {
                result_queues.* = try device.getQueueFamilies(self.instance, requirements.surface);
                picked_device_index = i;
                picked_device = device;
            }
        }

        if (picked_device != null) {
            return @intCast(picked_device_index);
        } else {
            return error.NoValidPhysicalDeviceFound;
        }
    }
};

fn getQueueCreateInfos(families: PhysicalDeviceQueueFamilyIndices, queue_create_infos: []vk.DeviceQueueCreateInfo) !u32 {
    //var queue_create_infos = [_]vk.DeviceQueueCreateInfo{undefined} ** 4;
    var count: usize = 0;

    const priority = [_]f32{1};

    if (families.graphics) |graphics| {
        queue_create_infos[count].s_type = .device_queue_create_info;
        queue_create_infos[count].queue_family_index = graphics;
        queue_create_infos[count].queue_count = 1;
        queue_create_infos[count].p_queue_priorities = &priority;
        count += 1;
    } else {
        return error.NoGraphicsQueueFound;
    }

    if (families.present) |present| {
        if (present != families.graphics.?) {
            queue_create_infos[count].s_type = .device_queue_create_info;
            queue_create_infos[count].queue_family_index = present;
            queue_create_infos[count].queue_count = 1;
            queue_create_infos[count].p_queue_priorities = &priority;
            count += 1;
        }
    } else {
        return error.NoPresentQueueFound;
    }

    return @intCast(count);
}

extern fn glfwCreateWindowSurface(instance: vk.Instance, window: *glfw.Window, allocation_callbacks: ?*const vk.AllocationCallbacks, surface: *vk.SurfaceKHR) vk.Result;
