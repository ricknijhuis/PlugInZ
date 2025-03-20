const std = @import("std");
const log = std.log;
const Engine = @import("engine").Engine;
const ApplicationCallbacks = @import("engine").ApplicationCallbacks;
const Application = @import("engine").Application;

pub fn main() !void {
    var application: Application = undefined;
    var engine: Engine = undefined;

    var callbacks = try ApplicationCallbacks.init();
    defer callbacks.deinit();

    engine = try Engine.init();
    defer engine.deinit();

    application = try Application.init(&callbacks, &engine);
    defer application.deinit(&engine);

    //engine.run();
}
