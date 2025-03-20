const std = @import("std");
const builtin = @import("builtin");
const log = std.log;
const fs = std.fs;
const options = @import("options");

const BoundedArray = std.BoundedArray;
const DynLib = std.DynLib;
const Engine = @import("engine.zig").Engine;

pub const ApplicationCallbacks = struct {
    lib: DynLib,
    initFn: *const fn (*Engine) bool,
    deinitFn: *const fn (*Engine) void,

    pub fn init() !ApplicationCallbacks {
        const lib_prefix = switch (builtin.os.tag) {
            .macos, .linux => "lib",
            else => "",
        };

        const lib_extension = switch (builtin.os.tag) {
            .macos => ".dylib",
            .windows => ".dll",
            .linux => ".so",
            else => @compileError("Platform not supported, no lib extension found"),
        };
        var buff: [fs.max_path_bytes]u8 = .{0} ** fs.max_path_bytes;
        const cwd_path = try std.fs.cwd().realpath(".", &buff);

        var lib = blk: for ([_][]const u8{ cwd_path, "zig-out/lib", "zig-out/bin" }) |path| {
            const lib_path = try std.fmt.bufPrint(buff[cwd_path.len..], "{s}{s}{s}{s}{s}", .{ path, fs.path.sep_str, lib_prefix, options.name, lib_extension });
            break :blk DynLib.open(lib_path) catch {
                continue;
            };
        } else {
            @panic("Fail to load app dll");
        };

        return .{
            .lib = lib,
            .initFn = lib.lookup(@FieldType(@This(), "initFn"), "init").?,
            .deinitFn = lib.lookup(@FieldType(@This(), "deinitFn"), "deinit").?,
        };
    }

    pub fn reload(self: *Application) !void {
        _ = self; // autofix
    }

    pub fn deinit(self: *ApplicationCallbacks) void {
        // self.initFn = undefined;
        // self.deinitFn = undefined;
        self.lib.close();
    }
};

pub const Application = struct {
    callbacks: *ApplicationCallbacks,

    pub fn init(app_callbacks: *ApplicationCallbacks, engine: *Engine) !Application {
        if (!app_callbacks.initFn(engine)) {
            return error.FailedToInitializeApplication;
        }

        return .{
            .callbacks = app_callbacks,
        };
    }

    pub fn deinit(self: *Application, engine: *Engine) void {
        self.callbacks.deinitFn(engine);
    }
};
