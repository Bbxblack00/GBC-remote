import argparse
import re
import sys
from pathlib import Path

from pyboy import PyBoy

from coverage import CoverageRecorder, excluded_section_names, load_code_labels

TEST_RUN_FINISHED_MARKER = 0xA5
TEST_PASSED = 0
TEST_NOT_RUN = 0xFF
FRAME_LIMIT = 3000
ENTRY_LABEL_PREFIX = "TestEntry_"
SYMBOL_LINE_PATTERN = re.compile(r"^([0-9A-Fa-f]{2}):([0-9A-Fa-f]{4})\s+(\S+)$")
EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_USAGE = 2


def load_symbols(symbol_path):
    symbols = {}
    for line in Path(symbol_path).read_text().splitlines():
        match = SYMBOL_LINE_PATTERN.match(line)
        if match:
            symbols[match.group(3)] = int(match.group(2), 16)
    return symbols


def collect_test_names(symbols):
    entries = sorted(
        (address, name[len(ENTRY_LABEL_PREFIX):])
        for name, address in symbols.items()
        if name.startswith(ENTRY_LABEL_PREFIX)
    )
    return [name for _, name in entries]


def run_test_rom(rom_path, symbols, test_count, recorder):
    emulator = PyBoy(str(rom_path), window="null")
    if recorder:
        recorder.attach(emulator)
    finished_address = symbols["wTestRunFinished"]
    elapsed_frames = 0
    while emulator.memory[finished_address] != TEST_RUN_FINISHED_MARKER and elapsed_frames < FRAME_LIMIT:
        emulator.tick(1, False)
        if recorder:
            recorder.flush()
        elapsed_frames += 1
    finished = emulator.memory[finished_address] == TEST_RUN_FINISHED_MARKER
    executed_count = emulator.memory[symbols["wTestCount"]]
    results_address = symbols["wTestResults"]
    results = [emulator.memory[results_address + index] for index in range(test_count)]
    emulator.stop(save=False)
    return finished, executed_count, results


def report(test_names, finished, executed_count, results):
    failures = 0
    for name, result in zip(test_names, results):
        if result == TEST_PASSED:
            print(f"PASS  {name}")
        elif result == TEST_NOT_RUN:
            failures += 1
            print(f"FAIL  {name}  (never executed)")
        else:
            failures += 1
            print(f"FAIL  {name}  (assertion #{result} of its file)")
    if not finished:
        print("FAIL  test run did not finish within the frame limit")
        return EXIT_FAILURE
    if executed_count != len(test_names):
        print(f"FAIL  executed {executed_count} tests, expected {len(test_names)}")
        return EXIT_FAILURE
    print(f"\n{len(test_names) - failures} passed, {failures} failed, {len(test_names)} total")
    return EXIT_FAILURE if failures else EXIT_SUCCESS


def parse_arguments(arguments):
    parser = argparse.ArgumentParser()
    parser.add_argument("rom")
    parser.add_argument("symbols")
    parser.add_argument("--map")
    parser.add_argument("--coverage-output")
    return parser.parse_args(arguments)


def main(arguments):
    options = parse_arguments(arguments)
    symbols = load_symbols(options.symbols)
    test_names = collect_test_names(symbols)
    recorder = None
    if options.coverage_output:
        labels = load_code_labels(options.map, excluded_section_names("."))
        recorder = CoverageRecorder(labels)
    finished, executed_count, results = run_test_rom(options.rom, symbols, len(test_names), recorder)
    exit_code = report(test_names, finished, executed_count, results)
    if recorder:
        passed = sum(1 for result in results if result == TEST_PASSED)
        recorder.save(options.coverage_output, {"passed": passed, "total": len(test_names)})
    return exit_code


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
