# Copyright Notice: simulation and test harnesses inspired by Dr. Duwe's RARS verification setup for Iowa State University's CPRE 3810 course.

from __future__ import annotations

import argparse
from dataclasses import dataclass
import re
from typing import Callable, Optional
import subprocess
import sys
from pathlib import Path
import os
import shlex

# NOTE: this regex is used for RARS traces and for Spike traces
RARS_FIRSTLINE_RE = re.compile(r"^\s*[0-9]*\s*\[inst #(?P<num>\d+)\]\s+(?P<instr>.+?)\s*$")
GHDL_FIRSTLINE_RE = re.compile(r"In clock cycle: (?P<cycle>[0-9]+)")

REGISTER_WRITE_RE = re.compile(r"Register Write to Reg: (?P<reg>[0-9A-Fa-fxX]+) Val: (?P<val>[0-9A-Fa-fxX]+)")
MEMORY_WRITE_RE = re.compile(r"Memory Write to Addr: (?P<addr>[0-9A-Fa-fxX]+) Val: (?P<val>[0-9A-Fa-fxX]+)")

NOP_RE = re.compile(r"Register Write to Reg: 0x00.*")

RARS_DONE_RE = re.compile(r"\[inst #(?P<inst>\d+)\] halt")
GHDL_DONE_RE = re.compile(r"Execution stopped at cycle (?P<cycle>[0-9]+)")

SPIKE_INST_RE = re.compile(
    r"^\s*core\s+\d+:\s+(?P<pc>0x[0-9A-Fa-f]+)\s+\((?P<bits>(?:0x)?[0-9A-Fa-f]+)\)\s+(?P<asm>.+?)\s*$"
)
SPIKE_REG_WRITE_RE = re.compile(r"^\s*x\s*(?P<reg>\d+)\s+(?P<val>0x[0-9A-Fa-f]+)\s*$")
SPIKE_REG_WRITE2_RE = re.compile(r"^\s*x(?P<reg>\d+)\s+(?P<val>0x[0-9A-Fa-f]+)\s*$")
SPIKE_MEM_WRITE_RE = re.compile(r"^\s*mem\s+(?P<addr>0x[0-9A-Fa-f]+)\s+(?P<val>0x[0-9A-Fa-f]+).*$")
SPIKE_MEM_WRITE2_RE = re.compile(r"^\s*mem\[(?P<addr>0x[0-9A-Fa-f]+)\]\s*=\s*(?P<val>0x[0-9A-Fa-f]+).*$")


def _parse_hex_int(s: str) -> Optional[int]:
    try:
        s = s.strip()
        if s.lower().startswith("0x"):
            s = s[2:]
        if not s:
            return None
        return int(s, 16)
    except ValueError:
        return None


def _sanitize_disasm(s: str) -> str:
    s = s.strip().lower()
    s = re.sub(r"\s+", " ", s)
    s = re.sub(r"[^0-9a-z\$\._: ,\+\-\(\)]", "", s)
    return s


def normalize_spike_commit_log(output: str) -> str:
    out_lines: list[str] = []

    inst_num = 0
    pending_mem: Optional[str] = None
    pending_reg: Optional[str] = None

    def flush_pending() -> None:
        nonlocal pending_mem, pending_reg
        if pending_mem is not None:
            out_lines.append(pending_mem)
        elif pending_reg is not None:
            out_lines.append(pending_reg)
        pending_mem = None
        pending_reg = None

    for raw_line in output.splitlines():
        line = raw_line.rstrip("\r\n")
        m_inst = SPIKE_INST_RE.match(line)
        if m_inst:
            flush_pending()
            inst_num += 1
            asm = _sanitize_disasm(m_inst.group("asm"))
            out_lines.append(f"[inst #{inst_num}] {asm}")
            continue

        m_mem = SPIKE_MEM_WRITE_RE.match(line) or SPIKE_MEM_WRITE2_RE.match(line)
        if m_mem:
            addr_i = _parse_hex_int(m_mem.group("addr"))
            val_i = _parse_hex_int(m_mem.group("val"))
            if addr_i is None or val_i is None:
                continue
            addr_i &= 0xFFFFFFFF
            val_i &= 0xFFFFFFFF
            pending_mem = f"Memory Write to Addr: 0x{addr_i:08X} Val: 0x{val_i:08X}"
            continue

        m_reg = SPIKE_REG_WRITE_RE.match(line) or SPIKE_REG_WRITE2_RE.match(line)
        if m_reg:
            reg_i = int(m_reg.group("reg"))
            val_i = _parse_hex_int(m_reg.group("val"))
            if val_i is None:
                continue
            val_i &= 0xFFFFFFFF
            pending_reg = f"Register Write to Reg: 0x{reg_i:02X} Val: 0x{val_i:08X}"
            continue

    flush_pending()
    return "\n".join(out_lines) + ("\n" if out_lines else "")


def strip_spike_reset_trampoline(trace_text: str) -> str:
    # Remove Spike's deterministic reset trampoline before jumping to the ELF entrypoint

    lines = trace_text.splitlines(keepends=True)

    i = 0
    while i < len(lines) and not RARS_FIRSTLINE_RE.match(lines[i]):
        i += 1

    mnemonics: list[str] = []
    inst_line_indexes: list[int] = []

    j = i
    while j < len(lines) and len(mnemonics) < 5:
        m = RARS_FIRSTLINE_RE.match(lines[j])
        if m:
            inst_line_indexes.append(j)
            instr = (m.group("instr") or "").strip()
            mnemonic = instr.split()[0].lower() if instr else ""
            mnemonics.append(mnemonic)
        j += 1

    if mnemonics != ["auipc", "addi", "csrr", "lw", "jr"]:
        return trace_text

    cut_from = inst_line_indexes[4] + 1
    return "".join(lines[cut_from:])

@dataclass
class CompareResult:
    success: bool
    mismatches: int
    max_mismatches: int
    rars_instructions: int
    ghdl_cycles: int
    messages: list[str]

    @property
    def cycles_per_instruction(self) -> float:
        if self.rars_instructions <= 0:
            return 0.0
        return float(self.ghdl_cycles) / float(self.rars_instructions)

class GHDLReader:
    def __init__(self, path: str):
        self.path = path
        self.stream = open(path, "r", encoding="utf-8", errors="replace")
        self.queue: list[str] = []
        self.cycle_number = 0

    def read_next(self):
        not_done = True
        while not_done:
            while len(self.queue) < 3:
                self.queue.append(self.stream.readline())

            if not self.queue[0]:
                return (None, None)

            cycle = GHDL_FIRSTLINE_RE.search(self.queue[0])
            if not cycle:
                ghdl_done = GHDL_DONE_RE.search(self.queue.pop(0))
                if ghdl_done:
                    self.cycle_number = int(ghdl_done.group("cycle")) + 1
                    return (None, None)
                return self.read_next()
            else:
                self.queue.pop(0)

            self.cycle_number = int(cycle.group("cycle")) + 1

            action = MEMORY_WRITE_RE.search(self.queue[0])
            if action:
                self.queue.pop(0)
            else:
                action = REGISTER_WRITE_RE.search(self.queue[0])
                if action:
                    self.queue.pop(0)

            if action and NOP_RE.search(action.group()):
                not_done = True
            else:
                not_done = False

        return cycle, action

    def close(self):
        self.stream.close()


class RARSReader:
    def __init__(self, path: str):
        self.path = path
        self.stream = open(path, "r", encoding="utf-8", errors="replace")
        self.queue: list[str] = []
        self.instruction_number = 1

    def read_next(self):
        not_done = True
        while not_done:
            while len(self.queue) < 3:
                self.queue.append(self.stream.readline())

            if not self.queue[0]:
                return (None, None)

            instruction = RARS_FIRSTLINE_RE.search(self.queue[0])
            if not instruction:
                rars_done = RARS_DONE_RE.search(self.queue.pop(0))
                if rars_done:
                    self.instruction_number = int(rars_done.group("inst"))
                    return (None, None)
                return self.read_next()
            else:
                self.queue.pop(0)

            self.instruction_number = int(instruction.group("num"))

            if "halt" in instruction.group("instr"):
                return (None, None)

            action = MEMORY_WRITE_RE.search(self.queue[0])
            if action:
                self.queue.pop(0)
            else:
                action = REGISTER_WRITE_RE.search(self.queue[0])
                if action:
                    self.queue.pop(0)
                else:
                    return self.read_next()

            if NOP_RE.search(action.group()):
                not_done = True
            else:
                not_done = False

        return (instruction, action)

    def close(self):
        self.stream.close()


def actions_equivalent(a: Optional[re.Match], b: Optional[re.Match]) -> bool:
    if (a is None) or (b is None):
        return False

    if (a.re == REGISTER_WRITE_RE) and (b.re == REGISTER_WRITE_RE):
        reg_a = _parse_hex_int(a.group("reg"))
        reg_b = _parse_hex_int(b.group("reg"))
        val_a = _parse_hex_int(a.group("val"))
        val_b = _parse_hex_int(b.group("val"))
        if None in (reg_a, reg_b, val_a, val_b):
            return a.group() == b.group()
        return (reg_a & 0xFFFFFFFF) == (reg_b & 0xFFFFFFFF) and (val_a & 0xFFFFFFFF) == (val_b & 0xFFFFFFFF)

    if (a.re == MEMORY_WRITE_RE) and (b.re == MEMORY_WRITE_RE):
        addr_a = _parse_hex_int(a.group("addr"))
        addr_b = _parse_hex_int(b.group("addr"))
        val_a = _parse_hex_int(a.group("val"))
        val_b = _parse_hex_int(b.group("val"))
        if None in (addr_a, addr_b, val_a, val_b):
            return a.group() == b.group()
        return (addr_a & 0xFFFFFFFF) == (addr_b & 0xFFFFFFFF) and (val_a & 0xFFFFFFFF) == (val_b & 0xFFFFFFFF)

    return a.group() == b.group()

class TraceComparer:
    def __init__(
        self,
        ghdl_file: str,
        rars_file: str,
        max_mismatches: int = 2,
        dedup_ghdl_writes: bool = False,
        output_handler: Callable[[str], None] = lambda s: None,
    ):
        self.ghdl_reader = GHDLReader(ghdl_file)
        self.rars_reader = RARSReader(rars_file)
        self.ghdl_path = ghdl_file
        self.rars_path = rars_file
        self.max_mismatches = max_mismatches
        self.dedup_ghdl_writes = dedup_ghdl_writes
        self.outfunc = output_handler
        self.mismatches = 0
        self.instruction_number = 1
        self.cycle_number = 0

        self.messages: list[str] = []

    def _emit(self, s: str) -> None:
        self.messages.append(s)
        self.outfunc(s)

    def print_error(self, cycle, inst, expected, actual, description: Optional[str]):
        self.mismatches += 1

        cycle_number = cycle.group("cycle") if cycle else "n/a"
        if inst:
            instruction_number = inst.group("num")
            instruction = inst.group("instr")
        else:
            instruction_number = "n/a"
            instruction = "n/a"

        self._emit(f"Cycle: {cycle_number}")
        self._emit(f"Reference instruction number: {instruction_number}    Instruction: {instruction}")
        self._emit(f"Expected: {expected}")
        self._emit(f"Got     : {actual}")
        if description:
            self._emit(description)
        self._emit("")

    def compare(self) -> CompareResult:
        last_ghdl_action: Optional[re.Match] = None
        last_ghdl_cycle_num: Optional[int] = None

        while self.mismatches < self.max_mismatches:
            (rars_instruction, rars_action) = self.rars_reader.read_next()
            (ghdl_cycle, ghdl_action) = self.ghdl_reader.read_next()

            # both end
            if (not ghdl_cycle) and (not rars_instruction):
                break

            if (not ghdl_cycle) and rars_instruction:
                exp = rars_action.group() if rars_action else "(no write)"
                self.print_error(ghdl_cycle, rars_instruction, exp, "Execution stopped", "GHDL execution ended prematurely")
                break

            if ghdl_cycle and (not rars_instruction):
                got = ghdl_action.group() if ghdl_action else "(no write)"
                self.print_error(ghdl_cycle, rars_instruction, "Execution stopped", got, "GHDL execution improperly continued")
                break

            if not rars_action or not ghdl_action:
                self.print_error(ghdl_cycle, rars_instruction, rars_action.group() if rars_action else "(no write)", ghdl_action.group() if ghdl_action else "(no write)", "Missing write")
                break

            # NOTE: probably safe to remove this overflow-related logic
            #if (rars_action.group() == ghdl_action.group()):
            #    continue

            # alignment logic and NOP resolution
            while True:
                if (not ghdl_cycle) and (not rars_instruction):
                    break

                if not ghdl_cycle:
                    self.print_error(ghdl_cycle, rars_instruction, rars_action.group() if rars_action else "(no write)", "Execution stopped", "GHDL execution ended prematurely")
                    break

                if not rars_instruction:
                    self.print_error(ghdl_cycle, rars_instruction, "Execution stopped", "Execution stopped", "GHDL   execution ended prematurely")
                    break

                if not rars_action or not ghdl_action:
                    self.print_error(ghdl_cycle, rars_instruction, rars_action.group() if rars_action else "(no write)", ghdl_action.group() if ghdl_action else "(no write)", "Missing write")
                    break

                if self.dedup_ghdl_writes and last_ghdl_action and ghdl_cycle:
                    try:
                        current_cycle_num = int(ghdl_cycle.group("cycle"))
                    except (TypeError, ValueError):
                        current_cycle_num = None
                    if (
                        current_cycle_num is not None
                        and last_ghdl_cycle_num is not None
                        and current_cycle_num == (last_ghdl_cycle_num + 1)
                        and actions_equivalent(ghdl_action, last_ghdl_action)
                    ):
                        ghdl_cycle, ghdl_action = self.ghdl_reader.read_next()
                        continue

                # NOTE: probably safe to remove this overflow-related logic
                #if (rars_action.group() == ghdl_action.group()):
                #    continue

                if actions_equivalent(rars_action, ghdl_action):
                    if NOP_RE.search(ghdl_action.group()):
                        ghdl_cycle, ghdl_action = self.ghdl_reader.read_next()
                        continue

                    if ghdl_cycle:
                        try:
                            last_ghdl_cycle_num = int(ghdl_cycle.group("cycle"))
                        except (TypeError, ValueError):
                            last_ghdl_cycle_num = None
                    else:
                        last_ghdl_cycle_num = None
                    last_ghdl_action = ghdl_action
                    break

                if NOP_RE.search(ghdl_action.group()):
                    ghdl_cycle, ghdl_action = self.ghdl_reader.read_next()
                    continue

                if NOP_RE.search(rars_action.group()):
                    rars_instruction, rars_action = self.rars_reader.read_next()
                    continue

                if (rars_action.re == MEMORY_WRITE_RE) and (ghdl_action.re == REGISTER_WRITE_RE):
                    self.print_error(ghdl_cycle, rars_instruction, rars_action.group(), ghdl_action.group(), "Wrote to incorrect structure")
                    break
                if (ghdl_action.re == MEMORY_WRITE_RE) and (rars_action.re == REGISTER_WRITE_RE):
                    self.print_error(ghdl_cycle, rars_instruction, rars_action.group(), ghdl_action.group(), "Wrote to incorrect structure")
                    break

                self.print_error(ghdl_cycle, rars_instruction, rars_action.group(), ghdl_action.group(), "Incorrect write")
                break

        self.instruction_number = int(self.rars_reader.instruction_number)
        self.cycle_number = int(self.ghdl_reader.cycle_number)

        self.rars_reader.close()
        self.ghdl_reader.close()

        success = self.mismatches == 0

        return CompareResult(
            success=success,
            mismatches=self.mismatches,
            max_mismatches=self.max_mismatches,
            rars_instructions=self.instruction_number,
            ghdl_cycles=self.cycle_number,
            messages=self.messages,
        )


@dataclass
class SimulationSummary:
    assembly_file: Path

    engine: str = "RARS"

    rars_success: bool = False
    ghdl_success: bool = False
    compare_success: bool = False

    rars_errors: Optional[list[str]] = None
    ghdl_errors: Optional[list[str]] = None
    compare_messages: Optional[list[str]] = None

    instruction_count: Optional[int] = None
    cycle_count: Optional[int] = None

class SimulationSummarizer:
    def __init__(self):
        print()
        print("     Assembly Source File     | Golden |  GHDL  | Compare |  CPI  |")
        print("------------------------------+--------+--------+---------+-------+")

    def print(self, summary: SimulationSummary) -> None:
        def format_result(success: Optional[bool]) -> str:
            if success is None:
                return " --- "
            return "pass" if success else "fail"
        
        if summary.engine == "spike":
            summary.instruction_count = summary.instruction_count - 4

        cycles_per_instruction: Optional[float] = None
        if summary.instruction_count and summary.cycle_count:
            cycles_per_instruction = summary.cycle_count / summary.instruction_count

        cycles_per_instruction_string = " n/a" if cycles_per_instruction is None else f"{cycles_per_instruction:4.02f}"

        assembly = str(summary.assembly_file)[-28:]
        print(f" {assembly:28} | {format_result(summary.rars_success):6} | {format_result(summary.ghdl_success):6} | {format_result(summary.compare_success):7} | {cycles_per_instruction_string}  |")

        print("------------------------------+--------+--------+---------+-------+")

        print(f"Testing file: {summary.assembly_file}")
        print(f"{summary.engine}: {format_result(summary.rars_success)}")
        if not summary.rars_success and summary.rars_errors:
            print(f"{summary.engine} errors:")
            for e in summary.rars_errors:
                print(e)

        print(f"GHDL: {format_result(summary.ghdl_success)}")
        if summary.ghdl_success is False and summary.ghdl_errors:
            print("GHDL errors:")
            for e in summary.ghdl_errors:
                print(e)

        if summary.compare_success is not None:
            print(f"Comparison: {format_result(summary.compare_success)}")
            if summary.compare_success is False and summary.compare_messages:
                print("\n".join(summary.compare_messages))

        if cycles_per_instruction is not None:
            print(f"Instruction Count: {summary.instruction_count}")
            print(f"Cycle Count:  {summary.cycle_count}")
            print(f"CPI: {cycles_per_instruction_string}")

        print("----------------------------------------------")


def compare_traces(ghdl_trace: str, rars_trace: str, max_mismatches: int = 2) -> CompareResult:
    dc = TraceComparer(ghdl_trace, rars_trace, max_mismatches=max_mismatches)
    return dc.compare()


def compare_traces_with_options(
    ghdl_trace: str,
    rars_trace: str,
    max_mismatches: int = 2,
    dedup_ghdl_writes: bool = False,
) -> CompareResult:
    dc = TraceComparer(
        ghdl_trace,
        rars_trace,
        max_mismatches=max_mismatches,
        dedup_ghdl_writes=dedup_ghdl_writes,
    )
    return dc.compare()

def find_rars_errors(output: str) -> list[str]:
    errors: list[str] = []
    for error in output.splitlines():
        if error.startswith("Error "):
            errors.append(error.rstrip())
    return errors

def ghdl_trace_completed(trace_path: Path) -> bool:
    if not trace_path.is_file():
        return False

    try:
        with trace_path.open("rb") as f:
            try:
                f.seek(0, 2)
                size = f.tell()
                f.seek(max(0, size - 8192), 0)
            except OSError:
                pass
            tail = f.read().decode("utf-8", errors="replace")
        if GHDL_DONE_RE.search(tail):
            return True

        text = trace_path.read_text(encoding="utf-8", errors="replace")
        return GHDL_DONE_RE.search(text) is not None
    except OSError:
        return False

def main() -> int:
    p = argparse.ArgumentParser()

    p.add_argument("--jar", required=True, help="Path to rars.jar")

    p.add_argument(
        "--engine",
        choices=["RARS", "spike"],
        default="RARS",
        help='Reference engine for generating the comparison trace (default: "RARS")',
    )
    p.add_argument("--elf", help="Path to RV32 ELF to run under Spike (required for --engine spike)")
    p.add_argument(
        "--spike-cmd",
        default=None,
        help='Spike command to run. On Windows you typically want "wsl spike"; on POSIX just "spike".',
    )
    p.add_argument("--spike-isa", default="rv32imac_zicsr", help="ISA string passed to spike --isa=...")
    p.add_argument(
        "--spike-log",
        choices=["log-custom-trace", "log-commits"],
        default="log-custom-trace",
        help=(
            "Spike logging mode. 'log-custom-trace' expects output lines like '[inst #..]' plus the "
            "existing 'Register Write...'/'Memory Write...' lines. 'log-commits' uses upstream "
            "Spike '-l --log-commits' and will be normalized."
        ),
    )
    p.add_argument(
        "--spike-mem",
        default=None,
        help=(
            "Spike memory layout for -m<layout>, e.g. "
            '"0x00400000:0x01000000,0x10010000:0x01000000". '
            "Needed when your ELF uses non-default physical addresses."
        ),
    )
    p.add_argument(
        "--spike-instructions",
        type=int,
        default=None,
        help="If set, pass --instructions=<n> to Spike to stop after n instructions (useful if your program ends in a trap loop).",
    )
    p.add_argument(
        "--print-cmd",
        action="store_true",
        help="Print the exact reference-engine command before running it (useful for debugging Spike/WSL).",
    )

    p.add_argument(
        "--assembly",
        "--asm",
        dest="assembly",
        required=True,
        help="Path to .s file",
    )

    p.add_argument("--trace", required=True, help="Where to write the full output trace")
    p.add_argument("--timeout", type=int, default=30, help="Timeout in seconds")
    p.add_argument("--java", default="java", help='Java executable to use (default: "java")')
    p.add_argument("--ghdl-trace", help="Path to the GHDL trace to compare against RARS")
    p.add_argument("--compare", action="store_true", help="Compare --ghdl-trace vs --trace after running RARS")
    p.add_argument("--max-mismatches", type=int, default=2, help="Max mismatches before failing comparison")
    p.add_argument(
        "--dedup-ghdl-writes",
        action="store_true",
        help=(
            "Enable a compatibility filter that drops back-to-back identical GHDL writes (cycle N and N+1). "
            "Disabled by default; use this when the DUT repeats the same WB for multiple cycles."
        ),
    )
    p.add_argument("--summary", action="store_true", help="Print a compact one-line summary")

    arguments = p.parse_args()

    jar = Path(arguments.jar).expanduser()
    assembly = Path(arguments.assembly).expanduser()
    trace = Path(arguments.trace).expanduser()

    summary = SimulationSummary(
        assembly_file=assembly,
        rars_errors=[],
        ghdl_errors=[],
        compare_messages=[],
    )
    summary.engine = arguments.engine

    if arguments.engine == "RARS":
        if not jar.is_file():
            print(f'Error: RARS jar not found: "{jar}"', file=sys.stderr)
            return 3
    if not assembly.is_file():
        print(f'Error: assembly file not found: "{assembly}"', file=sys.stderr)
        return 3

    trace.parent.mkdir(parents=True, exist_ok=True)

    def run_and_capture(cmd: list[str], timeout_s: int) -> tuple[bool, int, str]:
        try:
            proc = subprocess.run(
                cmd,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                timeout=timeout_s,
            )
            return (False, proc.returncode, proc.stdout or "")
        except FileNotFoundError:
            exe = cmd[0] if cmd else "(empty command)"
            return (False, 127, f"[error] Command not found: {exe}\n")
        except OSError as e:
            exe = cmd[0] if cmd else "(empty command)"
            return (False, 127, f"[error] Failed to run {exe}: {e}\n")
        except subprocess.TimeoutExpired as e:
            out = e.output
            if isinstance(out, bytes):
                out_s = out.decode(errors="replace")
            else:
                out_s = out or ""
            return (True, 124, out_s)

    summarizer = SimulationSummarizer()

    if arguments.engine == "RARS":
        command = [arguments.java, "-jar", str(jar), "nc", str(assembly)]
        is_timed_out, return_code, output = run_and_capture(command, arguments.timeout)
        if is_timed_out:
            output += f"\n[timeout] RARS exceeded {arguments.timeout}s\n"

        trace.write_text(output, encoding="utf-8", errors="replace")

        errors = find_rars_errors(output)
        summary.rars_errors = errors
        summary.rars_success = True

        if is_timed_out:
            print(f"RARS timed output after {arguments.timeout}s. Trace: {trace}", file=sys.stderr)
            summary.rars_success = False
            summarizer.print(summary)
            return 1

        if errors:
            print(f"RARS reported {len(errors)} error(s). Trace: {trace}", file=sys.stderr)
            for error in errors:
                print(error, file=sys.stderr)
            summary.rars_success = False
            summarizer.print(summary)
            return 1

    else:
        if not arguments.elf:
            print("Error: --engine spike requires --elf", file=sys.stderr)
            return 3

        elf_path = Path(arguments.elf).expanduser()
        if not elf_path.is_file():
            print(f'Error: ELF file not found: "{elf_path}"', file=sys.stderr)
            return 3

        spike_cmd_str = arguments.spike_cmd
        if spike_cmd_str is None:
            spike_cmd_str = "wsl spike" if os.name == "nt" else "spike"

        spike_cmd = shlex.split(spike_cmd_str, posix=(os.name != "nt"))
        if not spike_cmd:
            print("Error: invalid --spike-cmd", file=sys.stderr)
            return 3

        # Use an absolute Windows path so wslpath produces a correct /mnt/... path.
        elf_arg = str(elf_path.resolve())
        if os.name == "nt" and spike_cmd[0].lower() == "wsl":
            # Convert Windows path to /mnt/<drive>/... for the Linux-side Spike.
            try:
                # wslpath tends to behave better with forward slashes.
                win_for_wslpath = elf_arg.replace("\\", "/")
                p_conv = subprocess.run(
                    ["wsl", "wslpath", "-u", win_for_wslpath],
                    text=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    timeout=10,
                )
                converted = (p_conv.stdout or "").strip()
                if p_conv.returncode == 0 and converted.startswith("/"):
                    elf_arg = converted
                else:
                    # Fallback: manual conversion C:\foo\bar -> /mnt/c/foo/bar
                    m_drive = re.match(r"^(?P<drive>[A-Za-z]):[\\/](?P<rest>.*)$", elf_arg)
                    if m_drive:
                        drive = m_drive.group("drive").lower()
                        rest = m_drive.group("rest").replace("\\", "/")
                        elf_arg = f"/mnt/{drive}/{rest}"
            except OSError:
                pass

        if arguments.spike_log == "log-commits":
            log_args = ["-l", "--log-commits"]
        else:
            log_args = ["--log-custom-trace"]

        instructions_arg = [f"--instructions={arguments.spike_instructions}"] if arguments.spike_instructions else []
        mem_arg = [f"-m{arguments.spike_mem}"] if arguments.spike_mem else []

        command = [
            *spike_cmd,
            f"--isa={arguments.spike_isa}",
            *log_args,
            *mem_arg,
            *instructions_arg,
            elf_arg,
        ]

        if arguments.print_cmd:
            print("Spike command:")
            print("  " + " ".join(shlex.quote(part) for part in command))

        is_timed_out, return_code, output = run_and_capture(command, arguments.timeout)
        if is_timed_out:
            output += f"\n[timeout] Spike exceeded {arguments.timeout}s\n"

        trace_text = output
        if arguments.spike_log == "log-commits":
            trace_text = normalize_spike_commit_log(output)
        else:
            trace_text = strip_spike_reset_trampoline(trace_text)

        trace.write_text(trace_text, encoding="utf-8", errors="replace")

        has_trace = "[inst #" in trace_text
        summary.rars_success = (not is_timed_out) and has_trace
        summary.rars_errors = []
        if is_timed_out:
            summary.rars_errors.append(f"Spike timed out after {arguments.timeout}s")
        if return_code != 0:
            summary.rars_errors.append(f"Spike exited with code {return_code}")
            if output.strip().startswith("[error]"):
                summary.rars_errors.append(output.strip())
        if not has_trace:
            summary.rars_errors.append("Spike produced no usable trace output")

        if not summary.rars_success:
            summarizer.print(summary)
            return 1
    
    if not arguments.ghdl_trace:
        print("Error: --compare requires --ghdl-trace", file=sys.stderr)
        return 1

    ghdl_trace = Path(arguments.ghdl_trace).expanduser()
    if not ghdl_trace.is_file():
        print(f'Error: GHDL trace not found: "{ghdl_trace}"', file=sys.stderr)
        return 1
    
    summary.ghdl_success = ghdl_trace_completed(ghdl_trace)
    if not summary.ghdl_success:
        summary.ghdl_errors = [
            f'Trace did not contain expected stop marker (tb should write "Execution stopped at cycle ..."): {ghdl_trace}'
        ]

    comparison = compare_traces_with_options(
        ghdl_trace=str(ghdl_trace),
        rars_trace=str(trace),
        max_mismatches=arguments.max_mismatches,
        dedup_ghdl_writes=arguments.dedup_ghdl_writes,
    )

    summary.compare_success = comparison.success
    summary.compare_messages = comparison.messages
    summary.instruction_count = comparison.rars_instructions
    summary.cycle_count = comparison.ghdl_cycles

    summarizer.print(summary)

    if not comparison.success:
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
