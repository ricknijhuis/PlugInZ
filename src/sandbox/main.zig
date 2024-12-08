// const std = @import("std");

// const pluginz = @import("pluginz");
// const Engine = pluginz.Engine;
// const Window = pluginz.Window;
// const GraphicsSurface = pluginz.GraphicsSurface;
// const GraphicsPipeline = pluginz.GraphicsPipeline;
// const Renderer = pluginz.Renderer;

// pub fn main() !void {
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//     defer {
//         if (gpa.deinit() == .leak) {
//             @panic("Leaks detected");
//         }
//     }

//     const allocator = gpa.allocator();

//     try Engine.init(
//         allocator,
//         .{
//             .app_name = "Sandbox",
//             .app_version = "",
//             .asset_path = "assets",
//         },
//     );
//     defer Engine.deinit();

//     const window = try Window.init(.{
//         .title = "Sandbox",
//         .width = 800,
//         .height = 600,
//     });

//     const second_window = try Window.init(.{
//         .title = "Second Window",
//         .width = 1280,
//         .height = 720,
//     });

//     const surface = try GraphicsSurface.init(window, .{});
//     const second_surface = try GraphicsSurface.init(second_window, .{});

//     const vert_code align(4) = @embedFile("triangle.vert").*;
//     const frag_code align(4) = @embedFile("triangle.frag").*;

//     const pipeline = try GraphicsPipeline.init(&vert_code, &frag_code);

//     while (!Window.shouldClose(window)) {
//         Engine.pollEvents();

//         GraphicsPipeline.begin(pipeline);

//         GraphicsSurface.begin(surface);

//         try Renderer.draw();

//         GraphicsSurface.end();

//         GraphicsSurface.begin(second_surface);

//         try Renderer.draw();

//         GraphicsSurface.end();

//         GraphicsPipeline.end();
//     }
// }
