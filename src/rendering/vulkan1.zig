// const std = @import("std");
// const Platform = @import("pluginz.platform").Platform;
// const Window = @import("pluginz.platform").Window;

// const vk = @import("vulkan");
// const c = @import("c.zig");

// const required_device_extensions = [_][*:0]const u8{vk.extensions.khr_swapchain.name};
// const apis: []const vk.ApiInfo = &.{
//     .{
//         .base_commands = .{
//             .createInstance = true,
//         },
//         .instance_commands = .{
//             .createDevice = true,
//         },
//     },
//     vk.features.version_1_0,
//     vk.features.version_1_1,
//     vk.features.version_1_2,
//     vk.features.version_1_3,
//     vk.extensions.khr_surface,
//     vk.extensions.khr_swapchain,
//     vk.extensions.ext_debug_utils,
// };

// /// Next, pass the `apis` to the wrappers to create dispatch tables.
// const BaseDispatch = vk.BaseWrapper(apis);
// const InstanceDispatch = vk.InstanceWrapper(apis);
// const DeviceDispatch = vk.DeviceWrapper(apis);

// // Also create some proxying wrappers, which also have the respective handles
// const Instance = vk.InstanceProxy(apis);
// const Device = vk.DeviceProxy(apis);

// pub const Vulkan = struct {
//     allocator: std.mem.Allocator,
//     base: BaseDispatch,
//     instance: Instance,
//     device: Device,

//     graphics_queue_family: u32,
//     graphics_queue: vk.Queue,

//     present_queue_family: u32,
//     present_queue: vk.Queue,

//     debug_messenger: vk.DebugUtilsMessengerEXT,

//     physical_device: vk.PhysicalDevice,
//     physical_device_properties: vk.PhysicalDeviceProperties,
//     physical_device_mem_properties: vk.PhysicalDeviceMemoryProperties,

//     // should be changed per surface
//     surface: vk.SurfaceKHR,

//     pub fn init(platform: Platform, window: Window, params: struct {}) !*Vulkan {
//         _ = params; // autofix
//         const self = try platform.allocator.create(Vulkan);
//         self.allocator = platform.allocator;

//         self.base = try BaseDispatch.load(c.glfwGetInstanceProcAddress);

//         var glfw_extension_count: u32 = 0;
//         const glfw_extensions = c.glfwGetRequiredInstanceExtensions(&glfw_extension_count);
//         var extensions = try std.ArrayList([*c]const u8)
//             .initCapacity(self.allocator, glfw_extension_count + 1);

//         for (glfw_extensions[0..glfw_extension_count]) |ext| {
//             extensions.appendAssumeCapacity(ext);
//         }
//         try extensions.append(vk.extensions.ext_debug_utils.name);

//         const app_info = vk.ApplicationInfo{ .p_application_name = "test", .application_version = vk.makeApiVersion(0, 0, 0, 0), .p_engine_name = "engine", .engine_version = vk.makeApiVersion(0, 0, 0, 0), .api_version = vk.API_VERSION_1_3 };

//         const instance = try self.base.createInstance(&.{
//             .p_application_info = &app_info,
//             .enabled_extension_count = @intCast(extensions.items.len),
//             .pp_enabled_extension_names = @ptrCast(extensions.items.ptr),
//         }, null);

//         extensions.deinit();

//         const instance_dispatch = try self.allocator.create(InstanceDispatch);
//         errdefer self.allocator.destroy(instance_dispatch);

//         instance_dispatch.* = try InstanceDispatch.load(instance, self.base.dispatch.vkGetInstanceProcAddr);
//         self.instance = Instance.init(instance, instance_dispatch);
//         errdefer self.instance.destroyInstance(null);

//         self.debug_messenger = try self.createDebugCallback();

//         self.surface = try self.createSurface(@ptrCast(window.handle));
//         errdefer self.instance.destroySurfaceKHR(self.surface, null);

//         const candidate = try self.pickPhysicalDevice();
//         self.physical_device = candidate.device;
//         self.physical_device_properties = candidate.properties;
//         self.physical_device_mem_properties = self.instance.getPhysicalDeviceMemoryProperties(self.physical_device);

//         const device = try self.createDevice(candidate);

//         const device_dispatch = try self.allocator.create(DeviceDispatch);
//         errdefer self.allocator.destroy(device_dispatch);

//         device_dispatch.* = try DeviceDispatch.load(device, self.instance.wrapper.dispatch.vkGetDeviceProcAddr);

//         self.device = Device.init(device, device_dispatch);
//         errdefer self.device.destroyDevice(null);

//         self.graphics_queue_family = candidate.queue_families.graphics_family;
//         self.graphics_queue = self.device.getDeviceQueue(self.graphics_queue_family, 0);

//         self.present_queue_family = candidate.queue_families.present_family;
//         self.present_queue = self.device.getDeviceQueue(self.present_queue_family, 0);

//         return self;
//     }

//     pub fn deinit(self: Vulkan) void {
//         self.device.destroyDevice(null);
//         self.instance.destroySurfaceKHR(self.surface, null);
//         self.instance.destroyInstance(null);

//         self.allocator.destroy(self.device.wrapper);
//         self.allocator.destroy(self.instance.wrapper);
//     }

//     fn createSurface(self: *Vulkan, window: *c.GLFWwindow) !vk.SurfaceKHR {
//         var surface: vk.SurfaceKHR = undefined;
//         if (c.glfwCreateWindowSurface(self.instance.handle, window, null, &surface) != .success) {
//             return error.SurfaceInitFailed;
//         }

//         return surface;
//     }

//     fn pickPhysicalDevice(
//         self: Vulkan,
//     ) !DeviceCandidate {
//         const pdevs = try self.instance.enumeratePhysicalDevicesAlloc(self.allocator);
//         defer self.allocator.free(pdevs);

//         for (pdevs) |pdev| {
//             if (try checkSuitable(self, pdev)) |candidate| {
//                 return candidate;
//             }
//         }

//         return error.NoSuitableDevice;
//     }

//     fn checkSuitable(
//         self: Vulkan,
//         device: vk.PhysicalDevice,
//     ) !?DeviceCandidate {
//         if (!try self.checkExtensionSupport(device)) {
//             return null;
//         }

//         if (!try self.checkSurfaceSupport(device)) {
//             return null;
//         }

//         if (try self.allocateQueues(device)) |queue_families| {
//             const properties = self.instance.getPhysicalDeviceProperties(device);
//             return DeviceCandidate{
//                 .device = device,
//                 .properties = properties,
//                 .queue_families = queue_families,
//             };
//         }

//         return null;
//     }

//     fn checkExtensionSupport(
//         self: Vulkan,
//         device: vk.PhysicalDevice,
//     ) !bool {
//         const propsv = try self.instance.enumerateDeviceExtensionPropertiesAlloc(device, null, self.allocator);
//         defer self.allocator.free(propsv);

//         for (required_device_extensions) |ext| {
//             for (propsv) |props| {
//                 if (std.mem.eql(u8, std.mem.span(ext), std.mem.sliceTo(&props.extension_name, 0))) {
//                     break;
//                 }
//             } else {
//                 return false;
//             }
//         }

//         return true;
//     }

//     fn checkSurfaceSupport(
//         self: Vulkan,
//         device: vk.PhysicalDevice,
//     ) !bool {
//         var format_count: u32 = undefined;
//         _ = try self.instance.getPhysicalDeviceSurfaceFormatsKHR(device, self.surface, &format_count, null);

//         var present_mode_count: u32 = undefined;
//         _ = try self.instance.getPhysicalDeviceSurfacePresentModesKHR(device, self.surface, &present_mode_count, null);

//         return format_count > 0 and present_mode_count > 0;
//     }

//     fn allocateQueues(
//         self: Vulkan,
//         device: vk.PhysicalDevice,
//     ) !?QueueFamilyIndices {
//         const families = try self.instance.getPhysicalDeviceQueueFamilyPropertiesAlloc(device, self.allocator);
//         defer self.allocator.free(families);

//         var graphics_family: ?u32 = null;
//         var present_family: ?u32 = null;

//         for (families, 0..) |properties, i| {
//             const family: u32 = @intCast(i);

//             if (graphics_family == null and properties.queue_flags.graphics_bit) {
//                 graphics_family = family;
//             }

//             if (present_family == null and (try self.instance.getPhysicalDeviceSurfaceSupportKHR(device, family, self.surface)) == vk.TRUE) {
//                 present_family = family;
//             }
//         }

//         if (graphics_family != null and present_family != null) {
//             return QueueFamilyIndices{
//                 .graphics_family = graphics_family.?,
//                 .present_family = present_family.?,
//             };
//         }

//         return null;
//     }

//     fn createDevice(self: Vulkan, candidate: DeviceCandidate) !vk.Device {
//         const priority = [_]f32{1};
//         const qci = [_]vk.DeviceQueueCreateInfo{
//             .{
//                 .queue_family_index = candidate.queue_families.graphics_family,
//                 .queue_count = 1,
//                 .p_queue_priorities = &priority,
//             },
//             .{
//                 .queue_family_index = candidate.queue_families.present_family,
//                 .queue_count = 1,
//                 .p_queue_priorities = &priority,
//             },
//         };

//         const queue_count: u32 = if (candidate.queue_families.graphics_family == candidate.queue_families.present_family)
//             1
//         else
//             2;

//         return try self.instance.createDevice(candidate.device, &.{
//             .queue_create_info_count = queue_count,
//             .p_queue_create_infos = &qci,
//             .enabled_extension_count = required_device_extensions.len,
//             .pp_enabled_extension_names = @ptrCast(&required_device_extensions),
//         }, null);
//     }

//     fn createDebugCallback(self: Vulkan) !vk.DebugUtilsMessengerEXT {
//         return try self.instance.createDebugUtilsMessengerEXT(&.{
//             .message_severity = .{ .verbose_bit_ext = true },
//             .message_type = .{
//                 .general_bit_ext = true,
//                 .performance_bit_ext = true,
//                 .validation_bit_ext = true,
//             },
//             .pfn_user_callback = debugCallback,
//             .p_user_data = null,
//         }, null);
//     }
// };

// fn debugCallback(severity: vk.DebugUtilsMessageSeverityFlagsEXT, msg_type: vk.DebugUtilsMessageTypeFlagsEXT, callback_data: ?*const vk.DebugUtilsMessengerCallbackDataEXT, user_data: ?*anyopaque) callconv(.C) vk.Bool32 {
//     _ = msg_type; // autofix
//     _ = user_data; // autofix

//     if (callback_data) |data| {
//         if (data.p_message) |message| {
//             if (severity.verbose_bit_ext) {
//                 std.log.debug("{s}", .{message});
//             } else if (severity.info_bit_ext) {
//                 std.log.info("{s}", .{message});
//             } else if (severity.warning_bit_ext) {
//                 std.log.warn("{s}", .{message});
//             } else if (severity.error_bit_ext) {
//                 std.log.err("{s}", .{message});
//             } else {
//                 std.log.warn("{s}", .{message});
//             }
//         }
//     }

//     return vk.FALSE;
// }

// const DeviceCandidate = struct {
//     device: vk.PhysicalDevice,
//     properties: vk.PhysicalDeviceProperties,
//     queue_families: QueueFamilyIndices,
// };

// const QueueFamilyIndices = struct {
//     graphics_family: u32,
//     present_family: u32,
// };

// const Surface = struct {
//     surface: vk.SurfaceKHR,
//     surface_format: vk.SurfaceFormatKHR,
//     present_mode: vk.PresentModeKHR,
//     extent: vk.Extent2D,
//     handle: vk.SwapchainKHR,

//     swap_images: []SwapImage,
//     image_index: u32,
//     next_image_acquired: vk.Semaphore,

//     pub fn init(ctx: Vulkan, window: Window) !Surface {
//         _ = window; // autofix
//         _ = ctx; // autofix
//     }
// };

// const SwapImage = struct {
//     image: vk.Image,
//     view: vk.ImageView,
//     image_acquired: vk.Semaphore,
//     render_finished: vk.Semaphore,
//     frame_fence: vk.Fence,
// };
