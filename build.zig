const std = @import("std");
const log = std.log;

pub fn build(b: *std.Build) !void {
    // General options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const name = b.option([]const u8, "name", "Name of the app") orelse {
        log.err("Option 'name' is required", .{});
        return error.MissingOption;
    };

    const version = b.option([]const u8, "version", "Version of the application") orelse {
        log.err("Option 'version' is required", .{});
        return error.MissingOption;
    };

    // Validate if version is semantic
    const sem_ver = try std.SemanticVersion.parse(version);

    const options = b.addOptions();
    options.addOption([]const u8, "name", name);
    options.addOption([]const u8, "version", version);

    // Modules
    const options_mod = options.createModule();

    const pluginz_exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const pluginz_engine_mod = b.createModule(.{
        .root_source_file = b.path("src/pluginz/engine/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const pluginz_application_mod = b.createModule(.{
        .root_source_file = b.path("src/pluginz/application/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const pluginz_mod = b.addModule("pluginz", .{
        .root_source_file = b.path("src/pluginz/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Private modules
    pluginz_engine_mod.addImport("options", options_mod);
    pluginz_application_mod.addImport("options", options_mod);
    pluginz_application_mod.addImport("pluginz.engine", pluginz_engine_mod);

    // Public modules
    pluginz_mod.addImport("options", options_mod);
    pluginz_mod.addImport("pluginz.engine", pluginz_engine_mod);
    pluginz_mod.addImport("pluginz.application", pluginz_application_mod);

    // Exe
    pluginz_exe_mod.addImport("pluginz.engine", pluginz_engine_mod);
    pluginz_exe_mod.addImport("pluginz.application", pluginz_application_mod);
    pluginz_exe_mod.addImport("options", options_mod);

    // Artifacts
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = pluginz_exe_mod,
        .version = sem_ver,
    });

    b.installArtifact(exe);
}
