const std = @import("std");
const device = @import("devices.zig"); // run setup.py script if this file does not exist

pub const TargetKind = enum { native, stm32 };

pub const TargetConfig = struct {
    name: []const u8,
    target: std.Build.ResolvedTarget,
    kind: TargetKind,
    flags: []const []const u8,
};

pub const STM32Chip = struct {
    target: std.Target.Query,
    defines: []const []const u8,
    chip: device.ChipInfo,
    flags: []const []const u8,
};

pub fn get_stm32_chip(b: *std.Build, comptime device_id: []const u8) !STM32Chip {
    const chip: device.ChipInfo = device.get_chip_info(device_id);
    const cpu = comptime device.get_chip_cpu(device_id);

    const flags = &[_][]const u8{
        "-mcpu=" ++ cpu,
        "-nostdlib", // No standard libraries
        "-nostartfiles", // No startup files
        "-ffreestanding",
        "-Wall",
        "-Wextra",
        "-Wno-unused-parameter",
        "-fno-exceptions", // Disable C++ exceptions
        "-fno-rtti",
        "-ffunction-sections",
        "-fdata-sections",
        "-fno-sanitize=undefined",
        switch (is_cpu_thumb(cpu)) {
            true => "-mthumb",
            false => "-marm",
        },
    };

    const fpu_flags = fpu_flags: {
        if (std.mem.eql(u8, chip.fpu, "soft")) {
            break :fpu_flags &[_][]const u8{"-msoft-float"};
        } else if (std.mem.eql(u8, chip.fpu, "hard-fpv4-sp-d16")) {
            break :fpu_flags &[_][]const u8{ "-mfloat-abi=hard", "-mfpu=fpv4-sp-d16" };
        } else if (std.mem.eql(u8, chip.fpu, "hard-fpv5-d16")) {
            break :fpu_flags &[_][]const u8{ "-mfloat-abi=hard", "-mfpu=fpv5-d16" };
        } else if (std.mem.eql(u8, chip.fpu, "hard-fpv5-sp-d16")) {
            break :fpu_flags &[_][]const u8{ "-mfloat-abi=hard", "-mfpu=fpv5-sp-d16" };
        } else {
            unreachable;
        }
    };

    return STM32Chip{
        .target = get_stm32_target(cpu),
        .defines = try splitDefines(b.allocator, chip.defs),
        .chip = chip,
        .flags = try concatSlices(
            b.allocator,
            try concatSlices(
                b.allocator,
                try splitDefines(b.allocator, chip.cppflags),
                flags,
            ),
            fpu_flags,
        ),
    };
}

fn is_cpu_thumb(cpu: []const u8) bool {
    const thumbcpus = [_][]const u8{ "cortex-m0", "cortex-m0plus", "cortex-m3", "cortex-m4", "cortex-m7" };
    for (thumbcpus) |testcpu| {
        if (std.mem.eql(u8, cpu, testcpu)) {
            return true;
        }
    }
    return false;
}

pub fn get_stm32_target(comptime cpu: []const u8) std.Target.Query {
    return std.Target.Query{
        .cpu_arch = switch (is_cpu_thumb(cpu)) {
            true => .thumb,
            false => .arm,
        },
        .os_tag = .freestanding,
        .abi = .eabi,
        .cpu_model = std.Target.Query.CpuModel{
            .explicit = getCpuModel(cpu),
        },
    };
}

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

pub fn splitDefines(allocator: std.mem.Allocator, defines: []const u8) ![]const []const u8 {
    // Given a string of space-separated defines, return an array of string defines
    var tokens = std.mem.tokenizeScalar(u8, defines, ' ');
    var list = std.ArrayList([]const u8).init(allocator);

    while (tokens.next()) |token| {
        try list.append(token);
    }

    return list.toOwnedSlice();
}

pub fn concatSlices(allocator: std.mem.Allocator, sliceA: []const []const u8, sliceB: []const []const u8) ![]const []const u8 {
    // concatenate two arrays of strings
    var list = std.ArrayList([]const u8).init(allocator);

    try list.appendSlice(sliceA);
    try list.appendSlice(sliceB);
    return list.toOwnedSlice();
}
