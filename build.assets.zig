const std = @import("std");

pub fn addAssets(b: *std.Build, exe: *std.Build.Step.Compile) void {
    const shaders_dir = if (@hasDecl(@TypeOf(b.build_root.handle), "openIterableDir"))
        b.build_root.handle.openIterableDir("assets", .{}) catch @panic("Failed to open assets directory")
    else
        b.build_root.handle.openDir("assets", .{ .iterate = true }) catch @panic("Failed to open shaders directory");

    var file_it = shaders_dir.walk(b.allocator) catch @panic("Failed to iterate assets directory");
    while (file_it.next() catch @panic("Failed to iterate assets directory")) |entry| {
        if (entry.kind == .file) {
            const ext = std.fs.path.extension(entry.basename);
            if (std.mem.eql(u8, ext, ".glsl")) {
                const name = entry.basename[0 .. entry.basename.len - ext.len];
                std.debug.print("Found shader file to compile: {s}. Compiling with name: {s}\n", .{ entry.path, name });
                add_shader(b, exe, entry.path, name);
            }
        }
    }
}

fn add_shader(b: *std.Build, exe: *std.Build.Step.Compile, path: []const u8, name: []const u8) void {
    const dir = std.fs.path.dirname(path).?;
    const source = std.fmt.allocPrint(b.allocator, "assets/{s}", .{path}) catch @panic("OOM");
    const source_path = b.path(source);
    const destination = std.fmt.allocPrint(b.allocator, "assets/{s}/{s}.spv", .{ dir, name }) catch @panic("OOM");

    //const echo = b.addSystemCommand(&.{ "cmd", "/c", "\"echo %PATH%\"" });
    const shader_compilation = b.addSystemCommand(&.{"glslangValidator"});
    shader_compilation.addArg("-V");
    shader_compilation.addFileArg(source_path);
    shader_compilation.addArg("-o");
    const output = shader_compilation.addOutputFileArg(destination);

    exe.step.dependOn(&shader_compilation.step);

    exe.root_module.addAnonymousImport(name, .{ .root_source_file = output });
}
