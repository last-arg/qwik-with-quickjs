const std = @import("std");
const Step = std.build.Step;
const Builder = std.build.Builder;

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    // Thank you 'https://github.com/codehz/tjs/blob/%F0%9F%92%A5/build.zig#L244'.
    const quickjs = b.addStaticLibrary("quickjs", null);
    quickjs.disable_sanitize_c = true;
    // 'disable_stack_probing = false' is what was causing 'Illegal instruction ...' at runtime.
    quickjs.disable_stack_probing = true;
    quickjs.linkLibC();
    quickjs.defineCMacroRaw("CONFIG_BIGNUM");
    quickjs.defineCMacroRaw("CONFIG_VERSION=\"unknown\"");
    const quickjs_flags = [_][]const u8{"-Wno-everything"};
    quickjs.addCSourceFile("quickjs/quickjs.c", &quickjs_flags);
    quickjs.addCSourceFile("quickjs/libregexp.c", &quickjs_flags);
    quickjs.addCSourceFile("quickjs/libunicode.c", &quickjs_flags);
    quickjs.addCSourceFile("quickjs/cutils.c", &quickjs_flags);
    quickjs.addCSourceFile("quickjs/libbf.c", &quickjs_flags);
    {
        quickjs.defineCMacro("_GNU_SOURCE", null);
        quickjs.addCSourceFile("quickjs/quickjs-libc.c", &[_][]const u8{"-Wno-everything"});
    }
    quickjs.setTarget(target);
    quickjs.setBuildMode(mode);

    const exe = b.addExecutable("qwik-with-quickjs", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();
    exe.linkLibC();
    exe.linkLibrary(quickjs);
    exe.addIncludePath("quickjs");
    exe.addLibraryPath("quickjs");

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);

    const filename = "./qwik_render.c";
    exe.addCSourceFile(filename, &.{});
    const gen = GenerateStep.init(b, filename, "qwik_render.zig");
    exe.addPackage(gen.package);
}

// To generate quickjs C bytecode
// qjsc -N qwik_render -c -o qwik_render.c tmp/src/test_server_v1.js
// Generate zig extern defintions from quickjs bytecode C file
pub const GenerateStep = struct {
    step: Step,
    builder: *Builder,
    bytecode_path: []const u8,
    package: std.build.Pkg,
    output_file: std.build.GeneratedFile,

    pub fn init(builder: *Builder, bytecode_path: []const u8, out_path: []const u8) *GenerateStep {
        const self = builder.allocator.create(GenerateStep) catch unreachable;
        const full_out_path = std.fs.path.join(builder.allocator, &[_][]const u8{
            builder.build_root,
            builder.cache_root,
            out_path,
        }) catch unreachable;

        self.* = .{
            .step = Step.init(.custom, "generate-quickjs-bytecode", builder.allocator, make),
            .builder = builder,
            .bytecode_path = bytecode_path,
            .package = .{
                .name = "qwik_render",
                .source = .{ .generated = &self.output_file },
                .dependencies = null,
            },
            .output_file = .{
                .step = &self.step,
                .path = full_out_path,
            },
        };
        return self;
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(GenerateStep, "step", step);
        const cwd = std.fs.cwd();
        const src = try cwd.readFileAlloc(self.builder.allocator, self.bytecode_path, std.math.maxInt(usize));
        const out_file = try std.fs.createFileAbsolute(self.output_file.path.?, .{ .read = true, .exclusive = false });
        defer out_file.close();

        var iter = std.mem.split(u8, src, "\n");
        const line_start = "const uint32_t ";
        const size_str = "_size";
        while (iter.next()) |line| {
            if (!std.mem.startsWith(u8, line, line_start)) continue;
            var rest = line[line_start.len..];
            const eq_index = std.mem.indexOfScalar(u8, rest, '=') orelse continue;
            const var_name = std.mem.trim(u8, rest[0..eq_index], " \t");
            if (!std.mem.endsWith(u8, var_name, size_str)) continue;
            rest = rest[eq_index + 1 ..];
            const value_index = std.mem.indexOfScalar(u8, rest, ';') orelse continue;
            const count = std.fmt.parseUnsigned(usize, std.mem.trim(u8, rest[0..value_index], " \t"), 10) catch continue;

            var buf_stream = std.io.bufferedWriter(out_file.writer());
            const st = buf_stream.writer();
            try st.print("pub const {s} = {d};\n", .{ var_name, count });
            const arr_name = var_name[0 .. var_name.len - size_str.len];
            try st.print("pub extern const {s}: [{d}]u8;\n", .{ arr_name, count });
            try buf_stream.flush();
        }
    }
};
