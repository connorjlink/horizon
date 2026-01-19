from __future__ import annotations

import argparse
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Optional
import re


@dataclass
class Section:
    name: str
    vma: int
    size: int
    flags: str

    @property
    def end(self) -> int:
        return self.vma + self.size

    @property
    def has_contents(self) -> bool:
        # objdump uses "CONTENTS" for sections that exist in the file image.
        return "CONTENTS" in self.flags


_SECTION_HEADER_RE = re.compile(
    r"^\s*(?P<idx>\d+)\s+"  # index
    r"(?P<name>\S+)\s+"  # name
    r"(?P<size>[0-9A-Fa-f]{8,})\s+"  # size
    r"(?P<vma>[0-9A-Fa-f]{8,})\s+"  # vma
    r"(?P<lma>[0-9A-Fa-f]{8,})\s+"  # lma
    r"(?P<off>[0-9A-Fa-f]{8,})\s+"  # file off
    r"(?P<align>2\*\*\d+)\s*$"  # align
)


def _run_capture(cmd: list[str], *, cwd: Optional[Path] = None) -> tuple[int, str]:
    p = subprocess.run(cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, cwd=str(cwd) if cwd else None)
    return p.returncode, p.stdout or ""


def parse_objdump_sections(objdump_text: str) -> list[Section]:
    lines = objdump_text.splitlines()
    sections: list[Section] = []

    current: Optional[Section] = None
    pending_flags: list[str] = []

    def flush_current() -> None:
        nonlocal current, pending_flags
        if current is None:
            return
        current.flags = " ".join(pending_flags).strip()
        sections.append(current)
        current = None
        pending_flags = []

    for raw in lines:
        line = raw.rstrip("\r\n")
        m = _SECTION_HEADER_RE.match(line)
        if m:
            flush_current()
            name = m.group("name")
            size = int(m.group("size"), 16)
            vma = int(m.group("vma"), 16)
            current = Section(name=name, vma=vma, size=size, flags="")
            continue

        # Flags are printed on subsequent indented lines.
        if current is not None:
            if line.strip() == "":
                continue
            if line.startswith(" ") or line.startswith("\t"):
                pending_flags.append(line.strip())
                continue
            # Any other non-indented line means end of section table.
            flush_current()

    flush_current()
    return sections


def dump_section_bytes(objcopy: str, elf: Path, section: str, out_path: Path) -> None:
    cmd = [objcopy, f"--dump-section", f"{section}={out_path}", str(elf)]
    rc, out = _run_capture(cmd)
    if rc != 0:
        raise RuntimeError(f"objcopy failed dumping {section}:\n{out}")


def bytes_to_hex_words_le(data: bytes, *, words: int, pad_word: int = 0) -> list[str]:
    # Convert bytes to 32-bit little-endian words, padding to the requested word count.
    out: list[str] = []

    total_bytes_needed = words * 4
    if len(data) < total_bytes_needed:
        data = data + b"\x00" * (total_bytes_needed - len(data))
    elif len(data) > total_bytes_needed:
        data = data[:total_bytes_needed]

    for i in range(0, total_bytes_needed, 4):
        b0, b1, b2, b3 = data[i : i + 4]
        w = (b0) | (b1 << 8) | (b2 << 16) | (b3 << 24)
        out.append(f"{w & 0xFFFFFFFF:08x}")

    if len(out) < words:
        out.extend([f"{pad_word & 0xFFFFFFFF:08x}"] * (words - len(out)))
    return out


def build_image(
    *,
    sections: list[Section],
    base: int,
    size_bytes: int,
    elf: Path,
    objcopy: str,
    include_names: set[str],
) -> bytearray:
    img = bytearray(b"\x00" * size_bytes)

    # First account for NOBITS-style sections (no contents) by just reserving range.
    # Our img is already zeroed, so we just validate bounds.
    for s in sections:
        if s.name not in include_names:
            continue
        if s.size <= 0:
            continue
        start = s.vma - base
        end = s.end - base
        if start < 0:
            continue
        if end > size_bytes:
            raise RuntimeError(
                f"Section {s.name} (0x{s.vma:08x}..0x{s.end:08x}) overflows image base 0x{base:08x} size {size_bytes}"
            )

    # Then lay down file-backed contents.
    for s in sections:
        if s.name not in include_names:
            continue
        if s.size <= 0 or not s.has_contents:
            continue
        start = s.vma - base
        end = s.end - base
        if start < 0:
            continue
        if end > size_bytes:
            raise RuntimeError(
                f"Section {s.name} (0x{s.vma:08x}..0x{s.end:08x}) overflows image base 0x{base:08x} size {size_bytes}"
            )
        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td) / f"{s.name.strip('.').replace('/', '_')}.bin"
            dump_section_bytes(objcopy, elf, s.name, tmp)
            content = tmp.read_bytes()
            if len(content) != s.size:
                # objcopy can include padding; clamp to declared size.
                content = content[: s.size]
            img[start:end] = content

    return img


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Generate Horizon GHDL hex files from a linked RV32 ELF by extracting .text/.data-like sections and emitting 32-bit hex words."
    )

    ap.add_argument("--elf", required=True, help="Input ELF")
    ap.add_argument("--out-ihex", required=True, help="Output instruction hex file")
    ap.add_argument("--out-dhex", required=True, help="Output data hex file")

    ap.add_argument("--objcopy", default="riscv64-unknown-elf-objcopy", help="objcopy executable")
    ap.add_argument("--objdump", default="riscv64-unknown-elf-objdump", help="objdump executable")

    ap.add_argument("--text-base", default="0x00400000", help="Instruction memory base address (hex)")
    ap.add_argument("--data-base", default="0x10010000", help="Data memory base address (hex)")

    ap.add_argument(
        "--dwords",
        type=int,
        default=1024,
        help="Number of 32-bit words to emit for data memory (default matches ADDRESS_WIDTH=10)",
    )

    args = ap.parse_args()

    elf = Path(args.elf)
    out_i = Path(args.out_ihex)
    out_d = Path(args.out_dhex)

    if not elf.is_file():
        print(f'Error: ELF not found: "{elf}"', file=sys.stderr)
        return 2

    def parse_hex(s: str) -> int:
        s = s.strip().lower()
        if s.startswith("0x"):
            s = s[2:]
        return int(s, 16)

    text_base = parse_hex(args.text_base)
    data_base = parse_hex(args.data_base)

    rc, objdump_out = _run_capture([args.objdump, "-h", str(elf)])
    if rc != 0:
        print(objdump_out, file=sys.stderr)
        return rc

    sections = parse_objdump_sections(objdump_out)

    # Instruction image: cover exactly the linked .text span (rounded up to 4 bytes).
    text_secs = [s for s in sections if s.name == ".text" and s.size > 0]
    if not text_secs:
        # No code: still emit a single word to keep the loader happy.
        ihex_words = ["00000013"]
    else:
        text_end = max(s.end for s in text_secs)
        text_size = max(0, text_end - text_base)
        if text_size <= 0:
            ihex_words = ["00000013"]
        else:
            text_size_rounded = (text_size + 3) & ~3
            img_i = build_image(
                sections=sections,
                base=text_base,
                size_bytes=text_size_rounded,
                elf=elf,
                objcopy=args.objcopy,
                include_names={".text"},
            )
            ihex_words = bytes_to_hex_words_le(bytes(img_i), words=text_size_rounded // 4)

    # Data image: fixed-size 1024 words, overlay any data-like sections.
    dsize_bytes = int(args.dwords) * 4
    img_d = build_image(
        sections=sections,
        base=data_base,
        size_bytes=dsize_bytes,
        elf=elf,
        objcopy=args.objcopy,
        include_names={".data", ".rodata", ".sdata", ".sbss", ".bss"},
    )
    dhex_words = bytes_to_hex_words_le(bytes(img_d), words=int(args.dwords))

    out_i.parent.mkdir(parents=True, exist_ok=True)
    out_d.parent.mkdir(parents=True, exist_ok=True)

    out_i.write_text("\n".join(ihex_words) + "\n", encoding="utf-8")
    out_d.write_text("\n".join(dhex_words) + "\n", encoding="utf-8")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
