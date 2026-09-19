const std = @import("std");

const stm = @import("stm32.zig");

// List of all the available backends
pub const libopencm3 = @import("backends/libopencm3/backend.zig");
pub const stm32hal = @import("backends/stm32hal/backend.zig");

// An enum of all backends
pub const Backend = enum(u8) {
    native,
    libopencm3,
    stm32hal,

    pub fn toStr(e: @This()) []const u8 {
        switch (e) {
            .native => return "native",
            .libopencm3 => return "libopencm3",
            .stm32hal => return "stm32hal",
        }
    }
};

// A configuration structure that maps to a backend binary
pub const Config = struct {
    backend: Backend,
    chip: stm.TargetKind,
};

// A more formal version of the above that has no unneccesary context
const BackendConfigKey = struct {
    backend: Backend,
    chip_id: []const u8,
};

// Helper functions that the hash map needs to be able to use the above key
const BackendConfigKeyContext = struct {
    pub fn hash(_: @This(), key: BackendConfigKey) u32 {
        var h = std.hash.Fnv1a_32.init();  // <- change the hash algo according to your needs... (WyHash...)
        h.update(key.chip_id);
        return (h.final() & 0xFFFF << 15) + @intFromEnum(key.backend);
    }

    pub fn eql(_: @This(), a: BackendConfigKey, b: BackendConfigKey, _: usize) bool {
        return std.mem.eql(u8, a.chip_id, b.chip_id) and (a.backend == b.backend);
    }
};

// The result type that is emitted
pub const BackendResult = struct {
    backend: Backend,
    step: *std.Build.Step,
    clean: ?*std.Build.Step = null,

    lib_obj_path: ?std.Build.LazyPath = null,
    lib_compile: ?*std.Build.Step.Compile = null,
    linker_path: ?std.Build.LazyPath = null,

    pub fn link(self: *const @This(), b: *std.Build, exe: *std.Build.Step.Compile) void {
        switch (self.backend) {
            .native => {
                exe.linkLibC();
                exe.linkLibCpp();
                return;
            },
            .libopencm3 => {
                libopencm3.linkLibopencm3(b, exe, self.lib_obj_path.?);
                return;
            },
            .stm32hal => {
                stm32hal.linkStm32Hal(b, exe, self.lib_compile.?);
                return;
            }
        }
    }

    pub fn setLinker(self: *const @This(), exe: *std.Build.Step.Compile) void {
        switch (self.backend) {
            .native => {
                return;
            },
            .libopencm3 => {
                exe.setLinkerScript(self.linker_path.?);
                exe.entry = .{ .symbol_name = "reset_handler" };
            },
            .stm32hal => {
                exe.setLinkerScript(self.linker_path.?);
                exe.entry = .{ .symbol_name = "main" }; // TODO CHANGE THIS
            },
        }
    }
};

pub const BackendManager = struct {
    store: std.ArrayHashMap(BackendConfigKey, BackendResult, BackendConfigKeyContext, true),

    pub fn init(allocator: std.mem.Allocator) @This() {
        return @This(){
            .store = 
                std.ArrayHashMap(BackendConfigKey, BackendResult, BackendConfigKeyContext, true).init(allocator),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.store.deinit();
    } 

    pub fn addBackend(self: *@This(), b: *std.Build, context: Config, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) !BackendResult {
        const chip_id = switch (context.chip) {
            .native => "native",
            .stm32  => context.chip.stm32.defines.id,
        };
        const key = BackendConfigKey{
            .chip_id = chip_id,
            .backend = context.backend,
        };

        if (self.store.get(key)) |backend| {
            return backend;
        }

        const result = try createBackend(b, context, target, optimize);        
        try self.store.put(key, result);

        return result;
    }
};

pub fn createBackend(b: *std.Build, config: Config, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) !BackendResult {
    switch (config.backend) {
        .native => {
            const name = "backend-native";
            return BackendResult{
                .backend = .native,
                .step = b.step(name, "Native backend implementation"),
            };
        },
        .libopencm3 => {
            const step, const obj = try libopencm3.addLibopencm3(b, config.chip.stm32);
            const linker = try libopencm3.addLibopencm3Linker(b, 
                try stm.utils.splitDefines(b.allocator, config.chip.stm32.defines.defs),
            );

            return BackendResult{
                .backend = .libopencm3,
                .step = step,
                .clean = try libopencm3.clean(b),
                .lib_obj_path = obj,
                .linker_path = linker,
            };
        },
        .stm32hal => {
            const lib = try stm32hal.addStm32Hal(b, config.chip.stm32, target, optimize);
            const linker = try stm32hal.addStm32HalLinker(b, 
                try stm.utils.splitDefines(b.allocator, config.chip.stm32.defines.defs),
            );

            return BackendResult{
                .backend = .stm32hal,
                .step = &lib.step,
                .lib_compile = lib,
                .linker_path = linker,
            };
        }
    }
}
