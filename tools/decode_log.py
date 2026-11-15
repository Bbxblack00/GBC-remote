import sys
from pathlib import Path

LOG_OFFSET = 0x800
LOG_SIZE = 0x400
HEADER_SIZE = 8
ENTRY_SIZE = 4
ENTRY_COUNT = (LOG_SIZE - HEADER_SIZE) // ENTRY_SIZE
MAGIC = b"GBLG"
INDEX_OFFSET = 4
BOOT_COUNTER_OFFSET = 5
KEPT_FLAG = 0x80
BANK_COUNT_MASK = 0x7F
PRIMARY_SHIFT = 4
CLASS_MASK = 0x0F
EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_USAGE = 2
EVENT_NAMES = {1: "BOOT", 2: "PROBE", 3: "MOUNT", 4: "ERROR", 5: "SAVE"}
CLASS_NAMES = {0: "valid", 1: "unformatted", 2: "damaged", 3: "not checked"}
SAVE_NAMES = {
    1: "card created",
    2: "signal saved",
    3: "card and signal saved",
    4: "signal deleted",
    5: "card deleted",
}


def describe(event_type, argument):
    if event_type == 1:
        return f"{argument} SRAM banks"
    if event_type == 2:
        kept = "kept" if argument & KEPT_FLAG else "not kept"
        return f"{argument & BANK_COUNT_MASK} banks, SRAM {kept}"
    if event_type == 3:
        primary = CLASS_NAMES.get(argument >> PRIMARY_SHIFT, "?")
        backup = CLASS_NAMES.get(argument & CLASS_MASK, "?")
        return f"primary {primary}, backup {backup}"
    if event_type == 4:
        return f"error E{argument:02d}"
    if event_type == 5:
        return SAVE_NAMES.get(argument, f"kind {argument}")
    return f"argument {argument}"


def decode_log(image):
    region = image[LOG_OFFSET:LOG_OFFSET + LOG_SIZE]
    if region[:len(MAGIC)] != MAGIC:
        return None
    write_index = region[INDEX_OFFSET]
    boot_counter = region[BOOT_COUNTER_OFFSET] | (region[BOOT_COUNTER_OFFSET + 1] << 8)
    entries = []
    for step in range(ENTRY_COUNT):
        slot = (write_index + step) % ENTRY_COUNT
        start = HEADER_SIZE + slot * ENTRY_SIZE
        event_type, argument, boot_low, boot_high = region[start:start + ENTRY_SIZE]
        if event_type == 0:
            continue
        entries.append({
            "boot": boot_low | (boot_high << 8),
            "type": EVENT_NAMES.get(event_type, f"TYPE {event_type}"),
            "detail": describe(event_type, argument),
            "argument": argument,
        })
    return {"boot_counter": boot_counter, "write_index": write_index, "entries": entries}


def format_log(decoded):
    if decoded is None:
        return "No event log found in this file."
    lines = [f"boots counted: {decoded['boot_counter']}", f"entries: {len(decoded['entries'])}", ""]
    for entry in decoded["entries"]:
        lines.append(f"boot {entry['boot']:5d}  {entry['type']:<6} {entry['detail']}")
    return "\n".join(lines)


def main(arguments):
    if len(arguments) != 1:
        print("usage: decode_log.py <save_file.srm>")
        return EXIT_USAGE
    decoded = decode_log(Path(arguments[0]).read_bytes())
    print(format_log(decoded))
    return EXIT_FAILURE if decoded is None else EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
