const std = @import("std");
const glfw = @import("glfw");
const pluginz = @import("pluginz");

const Platform = pluginz.Platform;
const Window = pluginz.Window;
const Renderer = pluginz.Renderer;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var platform = try Platform.init(allocator);
    defer platform.deinit();

    var main_window = try Window.init(&platform, .{});
    defer main_window.deinit();

    var second_window = try Window.init(&platform, .{ .title = "test" });
    defer second_window.deinit();

    const renderer = try Renderer.init(&platform);
    defer renderer.deinit();
    // try renderer.addWindow(main_window);
    // try renderer.addWindow()
    printGpuInfo(renderer);

    try renderer.addWindow(&main_window);
    try renderer.addWindow(&second_window);

    while (!main_window.shouldClose()) {
        platform.pollEvents();
    }
}

pub fn printGpuInfo(renderer: *const Renderer) void {
    for (renderer.devices.devices) |device| {
        std.log.info("found: {s}", .{device.properties.device_name});
    }

    std.log.info("picked: {s}", .{renderer.devices.devices[0].properties.device_name});
}
