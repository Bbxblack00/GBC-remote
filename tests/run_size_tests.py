import sys
from pathlib import Path

from pyboy import PyBoy

from flow_harness import load_symbols

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_USAGE = 2
FULL_SRAM_KB = 128
KILOBYTES_PER_BANK = 8
SIGNAL_SLOT_COUNT = 30
BOOT_FRAMES = 200
BANK_COUNT_SYMBOL = "wSramBankCount"
SLOT_LIMIT_SYMBOL = "wSignalSlotLimit"


def variant_directory(build_root, kilobytes):
    if kilobytes == FULL_SRAM_KB:
        return Path(build_root)
    return Path(build_root) / f"sram-{kilobytes}kb"


def expected_values(kilobytes):
    banks = kilobytes // KILOBYTES_PER_BANK
    return banks, min(SIGNAL_SLOT_COUNT, 2 * banks - 1)


def measure(directory):
    symbols = load_symbols(directory / "gbc-remote.sym")
    emulator = PyBoy(str(directory / "gbc-remote.gbc"), window="null")
    emulator.tick(BOOT_FRAMES, False)
    banks = emulator.memory[symbols[BANK_COUNT_SYMBOL][1]]
    limit = emulator.memory[symbols[SLOT_LIMIT_SYMBOL][1]]
    emulator.stop(save=False)
    ram_file = Path(str(directory / "gbc-remote.gbc") + ".ram")
    ram_file.unlink(missing_ok=True)
    return banks, limit


def main(arguments):
    if len(arguments) < 2:
        print("usage: run_size_tests.py <build_root> <kilobytes>...")
        return EXIT_USAGE
    build_root = arguments[0]
    failures = 0
    for kilobytes in (int(value) for value in arguments[1:]):
        banks, limit = measure(variant_directory(build_root, kilobytes))
        expected_banks, expected_limit = expected_values(kilobytes)
        if (banks, limit) == (expected_banks, expected_limit):
            print(f"PASS  sram_{kilobytes}kb  banks={banks} signals={limit}")
        else:
            failures += 1
            print(f"FAIL  sram_{kilobytes}kb  banks={banks} signals={limit}, expected banks={expected_banks} signals={expected_limit}")
    print(f"\n{len(arguments) - 1 - failures} passed, {failures} failed")
    return EXIT_FAILURE if failures else EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
