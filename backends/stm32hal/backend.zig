const std = @import("std");
const stm = @import("../../stm32.zig");

const splitDefines = stm.utils.splitDefines;

// @src needs to be inside a function scope which is why this is cursed
const path_stm32hal = struct {
    fn dirname() []const u8 {
        return std.fs.path.dirname(@src().file).?;
    }
}.dirname();
const path_cube_driver = path_stm32hal ++ "/STM32CubeL4";

fn getHalName(allocator: std.mem.Allocator, chip: stm.STM32Chip) []const u8 {
    var family: [8]u8 = undefined;
    std.ascii.upperString(&family, chip.defines.family);
    const name = try std.fmt.allocPrint(allocator, "STM32Cube{s}", .{family});
    return name;
}

pub fn addCmsis(b: *std.Build, _: stm.STM32Chip, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) 
    !*std.Build.Step.Compile {

    // TODO Rename to cmsis_template
    const cmsis_build = b.addLibrary(.{
        .name = "cmsis",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        })
    });

    // Link include directories
    cmsis_build.addIncludePath(b.path(path_cube_driver ++ "/Drivers/CMSIS/Include"));
    cmsis_build.addIncludePath(b.path(path_cube_driver ++ "/Drivers/CMSIS/Device/ST/STM32L4xx/Include"));

    // Builds a template executable
    cmsis_build.root_module.addCMacro("STM32L4xx", "");
    cmsis_build.root_module.addCMacro("STM32L452xx", "");
    cmsis_build.addCSourceFile(.{
        .file = b.path(path_cube_driver ++ "/Drivers/CMSIS/Device/ST/STM32L4xx/Source/Templates/system_stm32l4xx.c"),
    });

    return cmsis_build;
}

pub fn addStm32Hal(b: *std.Build, c: stm.STM32Chip, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) 
    !*std.Build.Step.Compile {

    const lib_cmsis = try addCmsis(b, c, target, optimize);

    //TODO Renaming with chip to resolve conflicts
    // Building the HAL
    const hal_build = b.addLibrary(.{
        .name = "stm32hal",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });

    // Link CMSIS include directories
    hal_build.addIncludePath(b.path(path_cube_driver ++ "/Drivers/CMSIS/Include"));
    hal_build.addIncludePath(b.path(path_cube_driver ++ "/Drivers/CMSIS/Device/ST/STM32L4xx/Include"));
    hal_build.linkLibrary(lib_cmsis);

    // Link the HAL include directory
    hal_build.addIncludePath(b.path(path_cube_driver ++ "/Drivers/STM32L4xx_HAL_Driver/Inc"));

    // Link to the directory containing stm32l4xx_hal_conf.h
    hal_build.addIncludePath(b.path("src"));
    hal_build.root_module.addCMacro("STM32L476xx", "");
    hal_build.root_module.addCMacro("USE_HAL_DRIVER", "");

    const hal_sources_path = b.path(path_cube_driver ++ "/Drivers/STM32L4xx_HAL_Driver/Src");

    var dir = try std.fs.openDirAbsolute(
        hal_sources_path.getPath(b), 
        .{ .iterate = true },
    );
    defer dir.close();

    var it = dir.iterate();
    while (try it.next()) |file| {
        if (file.kind == .file and std.mem.endsWith(u8, file.name, ".c")) {
            hal_build.addCSourceFile(.{
                .file = hal_sources_path.path(b, file.name),
            });
        }
    }

    return hal_build;
}

pub fn linkStm32Hal(b: *std.Build, exe: *std.Build.Step.Compile, lib: *std.Build.Step.Compile) void {
    // Link CMSIS include directories
    exe.addIncludePath(b.path(path_cube_driver ++ "/Drivers/CMSIS/Include"));
    exe.addIncludePath(b.path(path_cube_driver ++ "/Drivers/CMSIS/Device/ST/STM32L4xx/Include"));

    // Link the HAL include directory
    exe.addIncludePath(b.path(path_cube_driver ++ "/Drivers/STM32L4xx_HAL_Driver/Inc"));

    // Link to the directory containing stm32l4xx_hal_conf.h
    exe.addIncludePath(b.path("src"));
    exe.root_module.addCMacro("STM32L452xx", "");
    exe.root_module.addCMacro("USE_HAL_DRIVER", "");

    exe.addAssemblyFile(
        b.path(path_cube_driver ++ "/Drivers/CMSIS/Device/ST/STM32L4xx/Source/Templates/gcc/startup_stm32l452xx.s"),
    );

    exe.linkLibrary(lib);
}

pub fn addStm32HalLinker(b: *std.Build, defines: []const []const u8) !std.Build.LazyPath {
    // generate a linker script for the model of processor being used
    const out_path = "linker.ld";

    // Use a C preprocessor to fill in values into the linker template provided by libopencm3
    //   Defines can be found using the genlink.py script in the DEFS mode.
    const run = b.addSystemCommand(&[_][]const u8{
        "zig", "cc",
        "-E",  "-P",
    });
    run.addArgs(defines);

    run.addArg(path_stm32hal ++ "/linker.ld.S");

    run.addArg("-o");
    const linker_script = run.addOutputFileArg(out_path);

    run.setName("Pre-process linker script");

    return linker_script;
}

// This doesnt need its own clean function since compilation is handled by zig
// pub fn clean(b: *std.Build) !*std.Build.Step {
// }

