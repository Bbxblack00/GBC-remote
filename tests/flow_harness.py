import re
import shutil
import tempfile
from pathlib import Path

from pyboy import PyBoy

BACKGROUND_MAP_BASE = 0x9800
BACKGROUND_MAP_ROW_STRIDE = 32
SCREEN_WIDTH_TILES = 20
SCREEN_HEIGHT_TILES = 18
GLYPH_SPACE = 0
GLYPH_LETTER_A = 1
GLYPH_DIGIT_0 = 27
GLYPH_SYMBOLS = {37: "=", 38: "?", 39: ".", 40: "-", 41: ":", 42: ">", 43: "!", 44: "_"}
UNKNOWN_GLYPH_CHARACTER = "#"
RAW_SAMPLE_NO_LIGHT = 0xFF
RAW_SAMPLE_LIGHT = 0xFD
SENSOR_REGISTER_A_NO_DETECTION = 0xFF
SENSOR_REGISTER_A_DETECTION = 0x00
SAMPLES_PER_BYTE = 8
SAMPLE_PAGE_COUNT = 16
SAMPLE_PAGE_SIZE_BYTES = 256
SAMPLE_BYTE_COUNT = SAMPLE_PAGE_COUNT * SAMPLE_PAGE_SIZE_BYTES
SAMPLE_COUNT = SAMPLE_BYTE_COUNT * SAMPLES_PER_BYTE
BUTTON_HOLD_FRAMES = 3
SETTLE_FRAMES = 6
SCREEN_WAIT_FRAME_LIMIT = 600
BOOT_FRAMES = 200
SYMBOL_LINE_PATTERN = re.compile(r"^([0-9A-Fa-f]{2}):([0-9A-Fa-f]{4})\s+(\S+)$")
CAPTURE_HOOK_SYMBOL = "Infrared_CaptureSamplesToBuffer.afterRead{}"
REPLAY_HOOK_SYMBOL = "Infrared_ReplaySamplesFromBuffer.beforeWrite{}"
DETECTION_SYMBOL = "Infrared_IsSignalDetected"
JINGLE_SYMBOL = "Jingle_PlaySuccess"
DETECTION_INVERT_INSTRUCTION_OFFSET = 2


def load_symbols(symbol_path):
    symbols = {}
    for line in Path(symbol_path).read_text().splitlines():
        match = SYMBOL_LINE_PATTERN.match(line)
        if match:
            symbols[match.group(3)] = (int(match.group(1), 16), int(match.group(2), 16))
    return symbols


def glyph_to_character(glyph):
    if glyph == GLYPH_SPACE:
        return " "
    if GLYPH_LETTER_A <= glyph < GLYPH_LETTER_A + 26:
        return chr(ord("A") + glyph - GLYPH_LETTER_A)
    if GLYPH_DIGIT_0 <= glyph < GLYPH_DIGIT_0 + 10:
        return str(glyph - GLYPH_DIGIT_0)
    return GLYPH_SYMBOLS.get(glyph, UNKNOWN_GLYPH_CHARACTER)


def build_pulse_levels(pulse_width, pulse_count):
    levels = []
    for index in range(pulse_count):
        levels.extend([index % 2 == 0] * pulse_width)
    return [1 if level else 0 for level in levels]


class SimulatedRemote:
    def __init__(self, emulator, symbols):
        self.emulator = emulator
        self.symbols = symbols
        self.signal_present = False
        self.levels = []
        self.sample_index = 0
        self.transmitted = []
        self.jingle_count = 0
        self.register_hook(DETECTION_SYMBOL, DETECTION_INVERT_INSTRUCTION_OFFSET, self.override_detection)
        for bit_index in range(SAMPLES_PER_BYTE):
            self.register_hook(CAPTURE_HOOK_SYMBOL.format(bit_index), 0, self.override_sample)
            self.register_hook(REPLAY_HOOK_SYMBOL.format(bit_index), 0, self.record_transmission)
        self.register_hook(JINGLE_SYMBOL, 0, self.count_jingle)

    def register_hook(self, symbol, offset, callback):
        bank, address = self.symbols[symbol]
        self.emulator.hook_register(bank, address + offset, callback, None)

    def arm(self, levels):
        self.levels = levels
        self.sample_index = 0
        self.signal_present = True

    def disarm(self):
        self.signal_present = False

    def override_detection(self, context):
        if self.signal_present:
            self.emulator.register_file.A = SENSOR_REGISTER_A_DETECTION
        else:
            self.emulator.register_file.A = SENSOR_REGISTER_A_NO_DETECTION

    def override_sample(self, context):
        level = self.levels[self.sample_index] if self.sample_index < len(self.levels) else 0
        self.sample_index += 1
        self.emulator.register_file.A = RAW_SAMPLE_LIGHT if level else RAW_SAMPLE_NO_LIGHT

    def record_transmission(self, context):
        self.transmitted.append(self.emulator.register_file.A)

    def count_jingle(self, context):
        self.jingle_count += 1


class Session:
    def __init__(self, rom_path, symbol_path, working_directory=None):
        self.symbols = load_symbols(symbol_path)
        self.owns_directory = working_directory is None
        self.directory = Path(working_directory or tempfile.mkdtemp(prefix="gbc-remote-flow-"))
        self.rom_path = self.directory / Path(rom_path).name
        if not self.rom_path.exists():
            shutil.copy(rom_path, self.rom_path)
        self.emulator = None
        self.remote = None

    def start(self, held_buttons=()):
        self.emulator = PyBoy(str(self.rom_path), window="null")
        self.remote = SimulatedRemote(self.emulator, self.symbols)
        for button in held_buttons:
            self.emulator.button_press(button)
        self.emulator.tick(BOOT_FRAMES, False)
        for button in held_buttons:
            self.emulator.button_release(button)

    def power_cycle(self, held_buttons=()):
        self.emulator.stop(save=True)
        self.start(held_buttons)

    def close(self):
        if self.emulator is not None:
            self.emulator.stop(save=False)
            self.emulator = None
        if self.owns_directory:
            shutil.rmtree(self.directory, ignore_errors=True)

    def row_text(self, row):
        base = BACKGROUND_MAP_BASE + row * BACKGROUND_MAP_ROW_STRIDE
        return "".join(glyph_to_character(self.emulator.memory[base + column]) for column in range(SCREEN_WIDTH_TILES))

    def screen_text(self):
        return [self.row_text(row) for row in range(SCREEN_HEIGHT_TILES)]

    def screen_contains(self, text):
        return any(text in line for line in self.screen_text())

    def press(self, button):
        self.emulator.button(button)
        self.emulator.tick(BUTTON_HOLD_FRAMES, False)

    def press_sequence(self, buttons):
        for button in buttons:
            self.press(button)

    def wait_for_text(self, text):
        for _ in range(SCREEN_WAIT_FRAME_LIMIT):
            if any(text in line for line in self.screen_text()):
                self.emulator.tick(SETTLE_FRAMES, False)
                return True
            self.emulator.tick(1, False)
        return False
