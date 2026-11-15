import json
import re
from pathlib import Path

SECTION_PATTERN = re.compile(r'^\s+SECTION: \$([0-9a-fA-F]+)-\$([0-9a-fA-F]+) \(\$[0-9a-fA-F]+ bytes\) \["(.+)"\]')
LABEL_PATTERN = re.compile(r'^\s+\$([0-9a-fA-F]+) = (\S+)$')
REGION_PATTERN = re.compile(r'^(\w+) bank #(\d+):')
SECTION_NAME_PATTERN = re.compile(r'SECTION\s+(?:FRAGMENT\s+|UNION\s+)?"([^"]+)"')
CODE_REGION = "ROM0"
ROM_BANK_ZERO = 0
HEADER_SECTION_NAMES = {"EntryPoint", "TestEntryPoint"}


def section_names_in(directory):
    names = set()
    for path in Path(directory).rglob("*.asm"):
        names.update(SECTION_NAME_PATTERN.findall(path.read_text()))
    return names


def excluded_section_names(project_directory):
    project = Path(project_directory)
    return (
        section_names_in(project / "src" / "data")
        | section_names_in(project / "tests")
        | HEADER_SECTION_NAMES
    )


def load_code_labels(map_path, excluded_sections):
    labels = {}
    region = None
    section = None
    for line in Path(map_path).read_text().splitlines():
        region_match = REGION_PATTERN.match(line)
        if region_match:
            region = region_match.group(1)
            section = None
            continue
        if region != CODE_REGION:
            continue
        section_match = SECTION_PATTERN.match(line)
        if section_match:
            section = section_match.group(3)
            continue
        label_match = LABEL_PATTERN.match(line)
        if label_match and section and section not in excluded_sections:
            labels[label_match.group(2)] = (section, int(label_match.group(1), 16))
    return labels


class CoverageRecorder:
    def __init__(self, labels):
        self.labels = labels
        self.hits = set()
        self.names_at = {}
        self.emulator = None
        self.pending_removals = set()
        for name, (_, address) in labels.items():
            self.names_at.setdefault(address, []).append(name)

    def attach(self, emulator, skip_addresses=()):
        self.emulator = emulator
        for address, names in self.names_at.items():
            if address in skip_addresses or self.hits.issuperset(names):
                continue
            emulator.hook_register(ROM_BANK_ZERO, address, self.record, address)

    def record(self, address):
        self.hits.update(self.names_at[address])
        self.pending_removals.add(address)

    def flush(self):
        while self.pending_removals:
            address = self.pending_removals.pop()
            try:
                self.emulator.hook_deregister(ROM_BANK_ZERO, address)
            except ValueError:
                continue

    def mark_address(self, address):
        self.hits.update(self.names_at.get(address, ()))

    def save(self, output_path, summary):
        payload = {"hits": sorted(self.hits)}
        payload.update(summary)
        Path(output_path).parent.mkdir(parents=True, exist_ok=True)
        Path(output_path).write_text(json.dumps(payload, indent=2))
