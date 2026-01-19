from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


LD_SCRIPT_TEMPLATE = """/* Auto-generated for Spike emulation */
OUTPUT_ARCH(riscv)

SECTIONS
{
  /* Match tb_processor.vhd load addresses */
  . = __TEXT_ADDR__;
  .text :
  {
    *(.text .text.*)
  }

  .rodata :
  {
    *(.rodata .rodata.*)
  }

  . = __DATA_ADDR__;
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
"""


def run(cmd: list[str]) -> int:
    p = subprocess.run(cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if p.stdout:
        # keep output for debugging when make runs
        sys.stdout.write(p.stdout)
    return p.returncode


def main() -> int:
    ap = argparse.ArgumentParser(description="Assemble+link a RV32 ELF suitable for Spike.")

    ap.add_argument("--asm", required=True, help="Input assembly .s")
    ap.add_argument("--out", required=True, help="Output ELF path")

    ap.add_argument("--as", dest="as_cmd", default="riscv64-unknown-elf-as", help="Assembler executable")
    ap.add_argument("--ld", dest="ld_cmd", default="riscv64-unknown-elf-ld", help="Linker executable")

    ap.add_argument("--march", default="rv32imac", help="-march passed to assembler")
    ap.add_argument("--mabi", default="ilp32", help="-mabi passed to assembler")

    ap.add_argument("--text-addr", default="0x00400000", help=".text start address (hex)")
    ap.add_argument("--data-addr", default="0x10010000", help=".data start address (hex)")

    args = ap.parse_args()

    asm_path = Path(args.asm).expanduser()
    out_path = Path(args.out).expanduser()

    if not asm_path.is_file():
        print(f'Error: assembly file not found: "{asm_path}"', file=sys.stderr)
        return 2

    out_path.parent.mkdir(parents=True, exist_ok=True)

    obj_path = out_path.with_suffix(".o")
    ld_script_path = out_path.with_suffix(".spike.ld")

    ld_script = LD_SCRIPT_TEMPLATE.replace("__TEXT_ADDR__", args.text_addr).replace("__DATA_ADDR__", args.data_addr)
    ld_script_path.write_text(ld_script, encoding="utf-8")

    as_cmd = [
        args.as_cmd,
        f"-march={args.march}",
        f"-mabi={args.mabi}",
        "-o",
        str(obj_path),
        str(asm_path),
    ]

    rc = run(as_cmd)
    if rc != 0:
        print("Assembler failed", file=sys.stderr)
        return rc

    # Force a 32-bit RISC-V ELF
    ld_cmd = [
        args.ld_cmd,
        "-m",
        "elf32lriscv",
        "-T",
        str(ld_script_path),
        "-e",
        args.text_addr,
        "-o",
        str(out_path),
        str(obj_path),
    ]

    rc = run(ld_cmd)
    if rc != 0:
        print("Linker failed", file=sys.stderr)
        return rc

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
