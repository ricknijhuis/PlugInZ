const std = @import("std");
const log = std.log;

const Engine = @import("pluginz.engine").Engine;
const ApplicationCallbacks = @import("pluginz.application").ApplicationCallbacks;
const Application = @import("pluginz.application").Application;

pub fn main() !void {
    var callbacks = try ApplicationCallbacks.init();
    defer callbacks.deinit();

    var engine = try Engine.init();
    defer engine.deinit();

    var app: Application = try .init(&callbacks, &engine);
    defer app.deinit(&engine);

    //engine.run();
}
