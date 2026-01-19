/* Auto-generated for Spike emulation */
OUTPUT_ARCH(riscv)

SECTIONS
{
  /* Match tb_processor.vhd load addresses */
  . = 0x00400000;
  .text :
  {
    *(.text .text.*)
  }

  .rodata :
  {
    *(.rodata .rodata.*)
  }

  . = 0x10010000;
  .data :
  {
    *(.data .data.*)
  }

  .bss :
  {
    *(.bss .bss.*)
    *(COMMON)
  }
}
