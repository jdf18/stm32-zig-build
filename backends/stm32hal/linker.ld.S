/*
 * STM32L452RET6 linker script
 *
 * This file is preprocessed by the C preprocessor.
 *
 * Expected defines:
 *
 *   _ROM_OFF
 *   _ROM
 *   _RAM_OFF
 *   _RAM
 *   _RAM2_OFF
 *   _RAM2
 *
 * Supplied for STM32L452RET6:
 *
 *   -DSTM32L4
 *   -DSTM32L452RET6
 *   -D_ROM=512K
 *   -D_RAM=128K
 *   -D_RAM2=32K
 *   -D_ROM_OFF=0x08000000
 *   -D_RAM_OFF=0x20000000
 *   -D_RAM2_OFF=0x10000000
 */

ENTRY(Reset_Handler)

/*
 * Force the vector table into the image.
 */
EXTERN(vector_table)


/*
 * Memory regions
 */
MEMORY
{
    rom  (rx)  : ORIGIN = _ROM_OFF,  LENGTH = _ROM
    ram  (rwx) : ORIGIN = _RAM_OFF,  LENGTH = _RAM
    ram2 (rwx) : ORIGIN = _RAM2_OFF, LENGTH = _RAM2
}


/*
 * Initial stack pointer.
 *
 * This points to the top of SRAM1.
 */
_estack = ORIGIN(ram) + LENGTH(ram);


/*
 * Minimum stack reservation.
 */
_min_stack_size = 0x400;


SECTIONS
{
    /*
     * --------------------------------------------------------------------
     * FLASH
     * --------------------------------------------------------------------
     */

    /*
     * Interrupt vector table and executable code.
     */
    .text :
    {
        . = ALIGN(4);

        KEEP(*(.isr_vector))
        KEEP(*(.vectors))

        *(.text)
        *(.text.*)

        *(.glue_7)
        *(.glue_7t)
        *(.gnu.linkonce.t.*)

        . = ALIGN(4);

        *(.rodata)
        *(.rodata.*)
        *(.gnu.linkonce.r.*)

        . = ALIGN(4);

    } >rom


    /*
     * C/C++ pre-initialisation functions.
     */
    .preinit_array :
    {
        . = ALIGN(4);

        __preinit_array_start = .;

        KEEP(*(.preinit_array))

        __preinit_array_end = .;

        . = ALIGN(4);
    } >rom


    /*
     * C++ static constructors.
     */
    .init_array :
    {
        . = ALIGN(4);

        __init_array_start = .;

        KEEP(*(SORT(.init_array.*)))
        KEEP(*(.init_array))

        __init_array_end = .;

        . = ALIGN(4);
    } >rom


    /*
     * C++ static destructors.
     */
    .fini_array :
    {
        . = ALIGN(4);

        __fini_array_start = .;

        KEEP(*(.fini_array))
        KEEP(*(SORT(.fini_array.*)))

        __fini_array_end = .;

        . = ALIGN(4);
    } >rom


    /*
     * ARM exception/unwind information.
     *
     * Normally empty when compiling with:
     *
     *   -fno-exceptions
     *   -fno-unwind-tables
     *   -fno-asynchronous-unwind-tables
     */
    .ARM.extab :
    {
        *(.ARM.extab*)
        *(.gnu.linkonce.armextab.*)
    } >rom


    .ARM.exidx :
    {
        __exidx_start = .;

        *(.ARM.exidx*)
        *(.gnu.linkonce.armexidx.*)

        __exidx_end = .;
    } >rom


    /*
     * End of the FLASH-resident portion.
     */
    . = ALIGN(4);

    _etext = .;


    /*
     * --------------------------------------------------------------------
     * SRAM1
     * --------------------------------------------------------------------
     */

    /*
     * Data which should not be initialised during reset.
     */
    .noinit (NOLOAD) :
    {
        . = ALIGN(4);

        *(.noinit)
        *(.noinit.*)

        . = ALIGN(4);

    } >ram


    /*
     * Initialised data.
     *
     * The data lives in SRAM1 at runtime but its initial contents
     * are stored in FLASH.
     */
    .data :
    {
        . = ALIGN(4);

        _sdata = .;

        *(.data)
        *(.data.*)
        *(.gnu.linkonce.d.*)

        . = ALIGN(4);

        _edata = .;

    } >ram AT>rom


    /*
     * Address of the initial .data contents in FLASH.
     */
    _sidata = LOADADDR(.data);


    /*
     * Zero-initialised data.
     */
    .bss (NOLOAD) :
    {
        . = ALIGN(4);

        _sbss = .;

        *(.bss)
        *(.bss.*)
        *(COMMON)

        . = ALIGN(4);

        _ebss = .;

    } >ram


    /*
     * Functions explicitly placed in RAM.
     */
    .ramtext :
    {
        . = ALIGN(4);

        *(.ramtext)
        *(.ramtext.*)

        . = ALIGN(4);

    } >ram AT>rom


    /*
     * --------------------------------------------------------------------
     * SRAM2
     * --------------------------------------------------------------------
     *
     * Place objects explicitly marked with:
     *
     *     __attribute__((section(".ram2")))
     *
     * into SRAM2.
     */
    .ram2 (NOLOAD) :
    {
        . = ALIGN(4);

        _sram2 = .;

        *(.ram2)
        *(.ram2.*)

        . = ALIGN(4);

        _eram2 = .;

    } >ram2


    /*
     * --------------------------------------------------------------------
     * Stack
     * --------------------------------------------------------------------
     */

    ._user_heap_stack (NOLOAD) :
    {
        . = ALIGN(8);

        PROVIDE(end = .);
        PROVIDE(_end = .);

        . = . + _min_stack_size;

        . = ALIGN(8);

    } >ram


    /*
     * --------------------------------------------------------------------
     * Unwanted sections
     * --------------------------------------------------------------------
     *
     * We are building a bare-metal Cortex-M application without
     * hosted C++ exception handling.
     */
    /DISCARD/ :
    {
        *(.eh_frame)
        *(.eh_frame.*)
    }
}


/*
 * Stack symbols.
 */
PROVIDE(_stack = ORIGIN(ram) + LENGTH(ram));


