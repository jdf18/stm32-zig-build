import yaml
import subprocess
from pathlib import Path

DIR = str(Path(__file__).parent.absolute())

GENERATED_DEVICE_FILE = DIR + "/devices.zig"

DATA_FIELDS = ["family", "subfamily", "cppflags", "defs", "cpu", "fpu"]

ZIG_CHIP_STRUCT = """pub const ChipInfo = struct {
    id: []const u8,
    family: []const u8,
    subfamily: []const u8,
    cppflags: []const u8,
    defs: []const u8,
    cpu: []const u8,
    fpu: []const u8,
    opencm3target: []const u8,
};\n\n"""

ZIG_CHIP_FN = """const std = @import("std");

pub fn get_chip_info(comptime id: []const u8) ChipInfo {
    for (chips) |chip| {
        if (std.mem.eql(u8, chip.id, id)) return chip;
    }
    unreachable;
}\n
pub fn get_chip_cpu(comptime id: []const u8) []const u8 {
    for (chips) |chip| {
        if (std.mem.eql(u8, chip.id, id)) return chip.cpu;
    }
    unreachable;
}\n\n"""

ZIG_CHIP_DATA_FORMAT = """.{{
    .id = "{name}",
    .family = "{family}",
    .subfamily = "{subfamily}",
    .cppflags = "{cppflags}",
    .defs = "{defs}",
    .cpu = "{cpu}",
    .fpu = "{fpu}",
    .opencm3target = "{cm3target}",
}},"""

indent = lambda string : '\n'.join(map(lambda line:(" "*4)+line, str(string).splitlines())) + '\n'

def get_chip_data(chip, field):
    return subprocess.check_output([
        "python", DIR + "/libopencm3/scripts/genlink.py",
        DIR + "/libopencm3/ld/devices.data",
        chip, field
    ]).decode().strip()

if __name__ == "__main__":
    with open("config.yaml") as f:
        data = yaml.safe_load(f)

    chips = data.get("chips", [])

    with open(GENERATED_DEVICE_FILE, "w") as f:
        f.write("// Generated file - do not edit\n\n")
        f.write(ZIG_CHIP_STRUCT)
        f.write(ZIG_CHIP_FN)

        f.write(f"pub const chips = [_]ChipInfo" + "{\n")
        for chip in chips:
            data = {field : get_chip_data(chip, field) for field in DATA_FIELDS}
            f.write(indent(ZIG_CHIP_DATA_FORMAT).format(
                name = chip, 
                cm3target=f"stm32/{data['family'][5:7]}", 
                **data
            ))
        f.write("};\n")