# Copyright Notice: simulation and test harnesses inspired by Dr. Duwe's RARS verification setup for Iowa State University's CPRE 3810 course.

from __future__ import annotations

import argparse
from dataclasses import dataclass
import re
from typing import Callable, Optional, Tuple
import subprocess
import sys
from pathlib import Path
from typing import Optional

RARS_FIRSTLINE_RE = re.compile(r"[0-9]*\[inst #(?P<num>[0-9]+)\] (?P<instr>[0-9$a-z ,\-\(\)]+)")
GHDL_FIRSTLINE_RE = re.compile(r"In clock cycle: (?P<cycle>[0-9]+)")

REGISTER_WRITE_RE = re.compile(r"Register Write to Reg: (?P<reg>[0-9A-Fa-fxX]+) Val: (?P<val>[0-9A-Fa-fxX]+)")
MEMORY_WRITE_RE = re.compile(r"Memory Write to Addr: (?P<addr>[0-9A-Fa-fxX]+) Val: (?P<val>[0-9A-Fa-fxX]+)")

NOP_RE = re.compile(r"Register Write to Reg: 0x00.*")

RARS_DONE_RE = re.compile(r"\[inst #(?P<inst>\d+)\] halt")
GHDL_DONE_RE = re.compile(r"Execution stopped at cycle (?P<cycle>[0-9]+)")

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

class TraceComparer:
    def __init__(
        self,
        ghdl_file: str,
        rars_file: str,
        max_mismatches: int = 2,
        output_handler: Callable[[str], None] = lambda s: None,
    ):
        self.ghdl_reader = GHDLReader(ghdl_file)
        self.rars_reader = RARSReader(rars_file)
        self.ghdl_path = ghdl_file
        self.rars_path = rars_file
        self.max_mismatches = max_mismatches
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
        self._emit(f"RARS instruction number: {instruction_number}    Instruction: {instruction}")
        self._emit(f"Expected: {expected}")
        self._emit(f"Got     : {actual}")
        if description:
            self._emit(description)
        self._emit("")

    def compare(self) -> CompareResult:
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

                # NOTE: probably safe to remove this overflow-related logic
                #if (rars_action.group() == ghdl_action.group()):
                #    continue

                if rars_action.group() == ghdl_action.group():
                    if NOP_RE.search(ghdl_action.group()):
                        ghdl_cycle, ghdl_action = self.ghdl_reader.read_next()
                        continue
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
        print("     Assembly Source File     |  RARS  |  GHDL  | Compare |  CPI  |")
        print("------------------------------+--------+--------+---------+-------+")

    def print(self, summary: SimulationSummary) -> None:
        def format_result(success: Optional[bool]) -> str:
            if success is None:
                return " --- "
            return "pass" if success else "fail"

        cycles_per_instruction: Optional[float] = None
        if summary.instruction_count and summary.cycle_count:
            cycles_per_instruction = summary.cycle_count / summary.instruction_count

        cycles_per_instruction_string = " n/a  |" if cycles_per_instruction is None else f"{cycles_per_instruction:5.02f}"

        assembly = str(summary.assembly_file)[-28:]
        print(f" {assembly:28} | {format_result(summary.rars_success):6} | {format_result(summary.ghdl_success):6} | {format_result(summary.compare_success):7} | {cycles_per_instruction_string:5}")

        print("------------------------------+--------+--------+---------+-------+")

        print(f"Testing file: {summary.assembly_file}")
        print(f"RARS: {format_result(summary.rars_success)}")
        if not summary.rars_success and summary.rars_errors:
            print("RARS errors:")
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

def find_rars_errors(output: str) -> list[str]:
    errors: list[str] = []
    for error in output.splitlines():
        if error.startswith("Error "):
            errors.append(error.rstrip())
    return errors


def main() -> int:
    p = argparse.ArgumentParser()

    p.add_argument("--jar", required=True, help="Path to rars.jar")

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

    if not jar.is_file():
        print(f'Error: RARS jar not found: "{jar}"', file=sys.stderr)
        return 3
    if not assembly.is_file():
        print(f'Error: assembly file not found: "{assembly}"', file=sys.stderr)
        return 3

    trace.parent.mkdir(parents=True, exist_ok=True)

    command = [arguments.java, "-jar", str(jar), "nc", str(assembly)]

    is_timed_out = False
    try:
        command_process = subprocess.run(
            command,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=arguments.timeout,
        )
        output = command_process.stdout or ""
    except subprocess.TimeoutExpired as e:
        is_timed_out = True
        output = e.output
        if isinstance(output, bytes):
            output = output.decode(errors="replace")
        else:
            output = output or ""
        output += f"\n[timeout] RARS exceeded {arguments.timeout}s\n"

    trace.write_text(output, encoding="utf-8", errors="replace")

    errors = find_rars_errors(output)
    summary.rars_errors = errors
    summary.rars_success = True
    summarizer = SimulationSummarizer()

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
    
    if not arguments.ghdl_trace:
        print("Error: --compare requires --ghdl-trace", file=sys.stderr)
        return 1

    ghdl_trace = Path(arguments.ghdl_trace).expanduser()
    if not ghdl_trace.is_file():
        print(f'Error: GHDL trace not found: "{ghdl_trace}"', file=sys.stderr)
        return 1

    comparison = compare_traces(
        ghdl_trace=str(ghdl_trace),
        rars_trace=str(trace),
        max_mismatches=arguments.max_mismatches,
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
