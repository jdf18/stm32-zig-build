const std = @import("std");

const device = @import("devices.zig"); // run setup.py script if this file does not exist

pub const utils = @import("utils.zig");
const splitDefines = utils.splitDefines;
const concatSlices = utils.concatSlices;


// Information regarding the specific STM chip being used
// pub const STM32Chip = struct {
//     target: std.Target.Query,
//     defines: []const []const u8,
//     chip: device.ChipDefines,
//     flags: []const []const u8,
// };

pub const STM32Chip = struct {
    display_name: []const u8,
    cpu_model: *const std.Target.Cpu.Model,
    defines: device.ChipDefines,
    flags: []const []const u8,
};

pub fn getSTM32Info(b: *std.Build, comptime device_id: []const u8) !STM32Chip {
    const defines = comptime device.get_chip_info(device_id);

    // Combine all the flags together to pass into the compiler later
    const cpp_flags = try splitDefines(b.allocator, defines.cppflags);
    const comp_flags = getCompileFlags(defines);
    const fpu_flags = getFpuFlags(defines);

    const all_flags = try concatSlices(
        b.allocator,
        try concatSlices(
            b.allocator,
            cpp_flags,
            comp_flags,
        ),
        fpu_flags,
    );
    return STM32Chip{
        .display_name = device_id,
        .cpu_model = getCpuModel(defines.cpu),
        .defines = defines,
        .flags = all_flags,
    };
}

// Type of target being built for, either native or STM
pub const TargetKind = union(enum) {
    native,
    stm32: STM32Chip,
};

pub fn resolveTarget(b: *std.Build, native_target: std.Build.ResolvedTarget, target: TargetKind) std.Build.ResolvedTarget {
    if (target == .native) return native_target;

    return b.resolveTargetQuery(.{
        .os_tag = .freestanding,
        .abi = .eabi,
        .cpu_arch = switch (isThumbCpu(target.stm32.defines.cpu)) {
            true => .thumb,
            false => .arm,
        },
        .cpu_model = .{ .explicit = target.stm32.cpu_model }
    });
}


fn isThumbCpu(cpu: []const u8) bool {
    const thumbcpus = [_][]const u8{ "cortex-m0", "cortex-m0plus", "cortex-m3", "cortex-m4", "cortex-m7" };
    for (thumbcpus) |testcpu| {
        if (std.mem.eql(u8, cpu, testcpu)) {
            return true;
        }
    }
    return false;
}

fn getCompileFlags(comptime defs: device.ChipDefines) []const []const u8 {
    const cpu = defs.cpu;

    return &[_][]const u8{
        "-mcpu=" ++ cpu,
        "-nostdlib", // No standard libraries
        // "-nostartfiles", // No startup files
        "-ffreestanding",
        "-Wall",
        "-Wextra",
        "-Wno-unused-parameter",
        "-fno-exceptions", // Disable C++ exceptions
        "-fno-rtti",
        "-ffunction-sections",
        "-fdata-sections",
        "-fno-sanitize=undefined",
        "-Wl,--gc-sections",
        switch (comptime isThumbCpu(cpu)) {
            true => "-mthumb",
            false => "-marm",
        },
    };
}

fn getFpuFlags(chip: device.ChipDefines) []const []const u8 {
    if (std.mem.eql(u8, chip.fpu, "soft")) {
        return &[_][]const u8{"-msoft-float"};
    } else if (std.mem.eql(u8, chip.fpu, "hard-fpv4-sp-d16")) {
        return &[_][]const u8{ "-mfloat-abi=hard", "-mfpu=fpv4-sp-d16" };
    } else if (std.mem.eql(u8, chip.fpu, "hard-fpv5-d16")) {
        return &[_][]const u8{ "-mfloat-abi=hard", "-mfpu=fpv5-d16" };
    } else if (std.mem.eql(u8, chip.fpu, "hard-fpv5-sp-d16")) {
        return &[_][]const u8{ "-mfloat-abi=hard", "-mfpu=fpv5-sp-d16" };
    } 
    unreachable;
}

// pub fn get_stm32_target(comptime cpu: []const u8) std.Target.Query {
//     return std.Target.Query{
//         .cpu_arch = switch (isThumbCpu(cpu)) {
//             true => .thumb,
//             false => .arm,
//         },
//         .os_tag = .freestanding,
//         .abi = .eabi,
//         .cpu_model = std.Target.Query.CpuModel{
//             .explicit = getCpuModel(cpu),
//         },
//     };
// }

fn getCpuModel(comptime model_name: []const u8) *const std.Target.Cpu.Model {
    // Return a cpu model object to create executables/libraries with from model name
    if (std.mem.eql(u8, model_name, "cortex-m0plus")) {
        return &std.Target.arm.cpu.cortex_m0plus;
    } else if (std.mem.eql(u8, model_name, "cortex-m0")) {
        return &std.Target.arm.cpu.cortex_m0;
    } else if (std.mem.eql(u8, model_name, "cortex-m4")) {
        return &std.Target.arm.cpu.cortex_m4;
    }
    unreachable;
}

