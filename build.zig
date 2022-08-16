const std = @import("std");

// from https://gist.github.com/DanB91/4236e82025bb21f2a0d7d72482e391d8
// pub const playdate_target = try std.zig.CrossTarget.parse(.{
//    .arch_os_abi = "thumb-freestanding-eabihf",
//    .cpu_features = "cortex_m7-fp64-fp_armv8d16-fpregs64-vfp2-vfp3d16-vfp4d16",
//});
pub const playdate_target = std.zig.CrossTarget{
    .cpu_arch = .thumb,
    .cpu_model = .{
        .explicit = &std.Target.arm.cpu.cortex_m7,
    },
    .cpu_features_add = std.Target.arm.featureSet(&.{.v7em}),
    .os_tag = .freestanding,
    .abi = .eabihf,
};
const eabi_features = "v7e-m+fp/hard/";

pub fn build(b: *std.build.Builder) !void {
    // https://developer.arm.com/tools-and-software/open-source-software/developer-tools/gnu-toolchain/downloads
    const arm_toolchain_path = std.os.getenv("ARM_TOOLCHAIN_PATH") orelse return error.ARM_TOOLCHAIN_PATH_NOT_SET;
    // https://play.date/dev/
    const playdate_sdk_path = std.os.getenv("PLAYDATE_SDK_PATH") orelse return error.PLAYDATE_SDK_PATH_NOT_SET;

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const lib = createLib("zig-playdate", "src/main.zig", b, playdate_sdk_path, arm_toolchain_path);
    lib.setBuildMode(mode);
    lib.install();
}

pub fn createLib(name: []const u8, root_src: ?[]const u8, b: *std.build.Builder, playdate_sdk_path: []const u8, arm_toolchain_path: []const u8, libc_txt_path: []const u8) *std.build.LibExeObjStep {
    const lib = b.addSharedLibrary(name, root_src, .unversioned);
    lib.setOutputDir("zig-out/lib");
    setupStep(b, lib, playdate_sdk_path, arm_toolchain_path, libc_txt_path);
    return lib;
}
pub fn createElf(b: *std.build.Builder, lib: *std.build.LibExeObjStep, playdate_sdk_path: []const u8, arm_toolchain_path: []const u8, libc_txt_path: []const u8) *std.build.LibExeObjStep {
    const game_elf = b.addExecutable("pdex.elf", null);
    game_elf.addObjectFile(b.pathJoin(&.{ lib.output_dir.?, b.fmt("{s}{s}", .{ lib.name, playdate_target.getObjectFormat().fileExt(playdate_target.cpu_arch.?) }) }));
    game_elf.step.dependOn(&lib.step);
    const c_args = [_][]const u8{
        "-DTARGET_PLAYDATE=1",
        "-DTARGET_EXTENSION=1",
    };
    game_elf.want_lto = false; // otherwise release build does not work
    game_elf.addCSourceFile(b.pathJoin(&.{ playdate_sdk_path, "/C_API/buildsupport/setup.c" }), &c_args);
    setupStep(b, game_elf, playdate_sdk_path, arm_toolchain_path, libc_txt_path);

    return game_elf;
}
fn setupStep(b: *std.build.Builder, step: *std.build.LibExeObjStep, playdate_sdk_path: []const u8, arm_toolchain_path: []const u8, libc_txt_path: []const u8) void {
    step.setLinkerScriptPath(.{ .path = b.pathJoin(&.{ playdate_sdk_path, "/C_API/buildsupport/link_map.ld" }) });
    step.addIncludeDir(b.pathJoin(&.{ arm_toolchain_path, "/arm-none-eabi/include" }));
    step.addLibPath(b.pathJoin(&.{ arm_toolchain_path, "/lib/gcc/arm-none-eabi/11.2.1/thumb/", eabi_features }));
    step.addLibPath(b.pathJoin(&.{ arm_toolchain_path, "/arm-none-eabi/lib/thumb/", eabi_features }));

    step.addIncludeDir(b.pathJoin(&.{ playdate_sdk_path, "C_API" }));
    step.setLibCFile(std.build.FileSource{ .path = libc_txt_path });

    step.setTarget(playdate_target);

    if (b.is_release) {
        step.omit_frame_pointer = true;
    }
    step.strip = true;
    step.link_function_sections = true;
    step.link_z_notext = true; // needed for @cos func
    step.stack_size = 61800;
}

pub const Paths = struct {
    assets_to_process: []const u8 = "assets",
    assets_to_copy_raw: []const u8 = "assets-raw",
    pdc_inputs_path: []const u8 = "pdc-input",
};

pub fn setupPDC(b: *std.build.Builder, game_elf: *std.build.LibExeObjStep, lib: *std.build.LibExeObjStep, playdate_sdk_path: []const u8, arm_toolchain_path: []const u8, game_name: []const u8, paths: Paths, simulator_target: ?std.zig.CrossTarget) ?*std.build.LibExeObjStep {
    const pdc_input = b.pathJoin(&.{ b.install_path, paths.pdc_inputs_path });
    const pdc_step = b.addSystemCommand(&.{ "bash", "-c", b.fmt("{s}/bin/pdc -sdkpath {0s} --skip-unknown {1s} zig-out/{2s}.pdx", .{ playdate_sdk_path, pdc_input, game_name }) });
    pdc_step.step.dependOn(&game_elf.step);

    const playdate_copy_step = b.addSystemCommand(&.{ "bash", "-c", b.fmt("mkdir -p {0s} && mv zig-out/lib/lib{2s}.so {0s}/pdex.so && {1s}/arm-none-eabi/bin/objcopy -O binary zig-out/bin/pdex.elf {0s}/pdex.bin", .{ pdc_input, arm_toolchain_path, lib.name }) });
    pdc_step.step.dependOn(&playdate_copy_step.step);

    const copy_assets_step = b.addSystemCommand(&.{ "bash", "-c", b.fmt("cp -r {0s}/* {1s}", .{ paths.assets_to_process, pdc_input }) });
    copy_assets_step.expected_exit_code = null;
    pdc_step.step.dependOn(&copy_assets_step.step);

    const copy_assets_raw_step = b.addSystemCommand(&.{ "bash", "-c", b.fmt("cp -r {0s}/* zig-out/{1s}.pdx", .{ paths.assets_to_copy_raw, game_name }) });
    copy_assets_raw_step.expected_exit_code = null;
    copy_assets_raw_step.step.dependOn(&pdc_step.step);
    b.getInstallStep().dependOn(&copy_assets_raw_step.step);

    if (simulator_target) |target| {
        const simulator_lib = b.addSharedLibrary("pdex", if (lib.root_src) |src| src.path else null, .unversioned);

        simulator_lib.setOutputDir(pdc_input);
        simulator_lib.setTarget(target);

        simulator_lib.addIncludeDir(b.pathJoin(&.{ playdate_sdk_path, "C_API" }));
        simulator_lib.linkLibC();
        simulator_lib.install();

        pdc_step.step.dependOn(&simulator_lib.step);
        return simulator_lib;
    }
    return null;
}
