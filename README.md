# stm32-zig-build

This is a collection of Zig scripts for helping compile firmware for the STM32 using [libopencm3](https://github.com/libopencm3/libopencm3) and the zig build system.

## Installation

Prerequisites:
- Python (>3.10)
- Zig (0.14.1 tested)

To download the project, run:
```bash
git clone --recurse-submodules https://github.com/jdf18/stm32-zig-build
```
Or to add to an existing git repo, run:
```bash
git submodule add https://github.com/jdf18/stm32-zig-build
git submodule update --init --recursive
```

## Using this tool

Before trying to compile, you need to generate a `devices.zig` file containing information regarding the target chip(s) you are using.
To do this:
1. Create a `config.yaml` in your project's root directory which states the chips you wish to include.<br>
*(A sample config.yaml file is present in this repo for reference.)*
2. You can then run: `python3 path/to/stm32-zig-build/setup.py` from your project root which will generate the `devices.zig` file.

For actually using this tool I have an example project repo [here](remind-me-to-fix-this-link) which i would recommend having a look at.

### config.yaml

The chip names here are used to look up defines in the device database provided by libopencm3 for linker script generation.
Make sure to use the full device part name but if you are having trouble, you can have a look through the database linked [here](https://github.com/libopencm3/libopencm3/blob/master/ld/devices.data).

## License

stm32-zig-build is is distributed under the MIT license. See the included [LICENSE](https://github.com/jdf18/stm32-zig-build/blob/main/LICENSE) file for details.
