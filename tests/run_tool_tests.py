import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools"))

from decode_log import ENTRY_COUNT, ENTRY_SIZE, HEADER_SIZE, LOG_OFFSET, LOG_SIZE, MAGIC, decode_log, format_log

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
RAM_SIZE_BYTES = 0x8000


def build_image(entries, write_index, boot_counter, magic=MAGIC):
    image = bytearray(RAM_SIZE_BYTES)
    region = bytearray(LOG_SIZE)
    region[:len(magic)] = magic
    region[4] = write_index
    region[5] = boot_counter & 0xFF
    region[6] = boot_counter >> 8
    for slot, (event_type, argument, boot) in entries.items():
        start = HEADER_SIZE + slot * ENTRY_SIZE
        region[start:start + ENTRY_SIZE] = bytes([event_type, argument, boot & 0xFF, boot >> 8])
    image[LOG_OFFSET:LOG_OFFSET + LOG_SIZE] = region
    return bytes(image)


def check_wrong_magic():
    return decode_log(build_image({}, 0, 0, magic=b"XXXX")) is None


def check_chronological_order():
    decoded = decode_log(build_image({0: (1, 4, 1), 1: (4, 3, 1), 2: (1, 4, 2)}, 3, 2))
    return [entry["type"] for entry in decoded["entries"]] == ["BOOT", "ERROR", "BOOT"]


def check_wrapped_log_starts_at_the_write_index():
    entries = {slot: (5, slot % 5 + 1, 1) for slot in range(ENTRY_COUNT)}
    decoded = decode_log(build_image(entries, 10, 1))
    first = decoded["entries"][0]
    return len(decoded["entries"]) == ENTRY_COUNT and first["argument"] == 10 % 5 + 1


def check_boot_counter_is_sixteen_bit():
    return decode_log(build_image({}, 0, 0x1234))["boot_counter"] == 0x1234


def check_error_description():
    decoded = decode_log(build_image({0: (4, 8, 1)}, 1, 1))
    return decoded["entries"][0]["detail"] == "error E08"


def check_mount_description():
    decoded = decode_log(build_image({0: (3, 0x20 | 0x00, 1)}, 1, 1))
    return decoded["entries"][0]["detail"] == "primary damaged, backup valid"


def check_text_report():
    report = format_log(decode_log(build_image({0: (1, 4, 1)}, 1, 1)))
    return "boot     1  BOOT   4 SRAM banks" in report and format_log(None).startswith("No event log")


CHECKS = [
    check_wrong_magic,
    check_chronological_order,
    check_wrapped_log_starts_at_the_write_index,
    check_boot_counter_is_sixteen_bit,
    check_error_description,
    check_mount_description,
    check_text_report,
]


def main():
    failures = 0
    for check in CHECKS:
        if check():
            print(f"PASS  {check.__name__}")
        else:
            failures += 1
            print(f"FAIL  {check.__name__}")
    print(f"\n{len(CHECKS) - failures} passed, {failures} failed, {len(CHECKS)} total")
    return EXIT_FAILURE if failures else EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main())
