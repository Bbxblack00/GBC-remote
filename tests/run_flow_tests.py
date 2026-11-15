import argparse
import sys
import traceback
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools"))

from decode_log import decode_log
from coverage import CoverageRecorder, excluded_section_names, load_code_labels
from flow_harness import RAM_BANK_SIZE_BYTES, SAMPLE_COUNT, Session, build_pulse_levels

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_USAGE = 2
CARD_COUNT = 32
CARD_ENTRY_SIZE = 12
SIGNAL_ENTRY_SIZE = 13
SIGNALS_PER_CARD = 8
SIGNAL_SLOTS = 30
FIVE_CARDS = 5
CHECKSUM_SEED = 0xC3
DIRECTORY_SIGNATURE = bytes([0x47, 0x42, 0x43, 0x52])
USED_ENTRY_STATUS = 0xA5
DIRECTORY_SIZE_BYTES = 4 + 32 * 12 + 30 * 13 + 1
DIRECTORY_BACKUP_OFFSET = 0x400
PROBE_OFFSET_IN_BANK = 0xF00
WIPED_MARKER_BANK = 5
PULSE_WIDTH_SAMPLES = 3
PULSE_COUNT = 40
REPLAY_WAIT_FRAMES = 30
QUIET_LEVELS = [0] * 64
WAITING_TEXT = "WAITING FOR SIGNAL"
NAME_CARD_TITLE = "NAME THE CARD"
NAME_SIGNAL_TITLE = "NAME THE SIGNAL"
CARD_LIST_LEGEND = "A=OPEN"
SIGNAL_LIST_LEGEND = "A=OK B=BACK"
DELETE_SIGNAL_TEXT = "DELETE SIGNAL?"
DELETE_CARD_TEXT = "DELETE CARD?"
DELETE_CARD_SURE_TEXT = "ARE YOU SURE?"
DISCARD_CARD_TEXT = "DISCARD CARD?"
EMPTY_CARD_TEXT = "EMPTY CARD"
LIST_FIRST_ROW = 2
LIST_VISIBLE_ROWS = 14
LIST_NAME_COLUMN = 3
TITLE_ROW = 0
TITLE_COLUMN = 1
NAME_LENGTH = 11
KEYS_A = ["a"]
KEYS_B = ["right", "a"]
KEYS_AB = ["a", "right", "a"]
KEYS_SPACE = ["left", "a"]
KEYS_SPACE_AFTER_B = ["left", "left", "a"]


def expect(condition, message):
    if not condition:
        raise AssertionError(message)


def list_names(session):
    names = []
    for row in range(LIST_FIRST_ROW, LIST_FIRST_ROW + LIST_VISIBLE_ROWS):
        text = session.row_text(row)[LIST_NAME_COLUMN:LIST_NAME_COLUMN + NAME_LENGTH].strip()
        if text:
            names.append(text)
    return names


def pulse_levels():
    return build_pulse_levels(PULSE_WIDTH_SAMPLES, PULSE_COUNT)


def capture_signal(session, expected_title):
    expect(session.wait_for_text(WAITING_TEXT), "reception screen not shown")
    session.remote.arm(pulse_levels())
    expect(session.wait_for_text(expected_title), f"{expected_title} not shown after the capture")
    session.remote.disarm()


def create_first_card(session, card_keys, signal_keys):
    capture_signal(session, NAME_CARD_TITLE)
    session.press_sequence(card_keys)
    session.press("start")
    expect(session.wait_for_text(NAME_SIGNAL_TITLE), "signal naming not shown after the card name")
    session.press_sequence(signal_keys)
    session.press("start")
    expect(session.wait_for_text(CARD_LIST_LEGEND), "card list not shown after the first signal")


def add_signal_to_open_card(session, keys):
    session.press("start")
    capture_signal(session, NAME_SIGNAL_TITLE)
    session.press_sequence(keys)
    session.press("start")


def add_empty_card(session, keys):
    session.press("start")
    expect(session.wait_for_text(NAME_CARD_TITLE), "card naming not shown")
    session.press_sequence(keys)
    session.press("start")
    expect(session.wait_for_text(CARD_LIST_LEGEND), "card list not shown after creating a card")


def open_card(session):
    session.press("a")
    expect(session.wait_for_text(SIGNAL_LIST_LEGEND), "signal list not shown after opening a card")


def scenario_first_launch_enters_reception(session):
    expect(session.wait_for_text(WAITING_TEXT), "reception screen not shown on first launch")


def scenario_quiet_signal_reports_error_three(session):
    session.wait_for_text(WAITING_TEXT)
    session.remote.arm(QUIET_LEVELS)
    expect(session.wait_for_text("ERROR E03"), "error E03 not displayed for a quiet capture")
    expect(session.screen_contains("MOVE THE REMOTE"), "error E03 advice missing")
    session.remote.disarm()
    session.press("a")
    expect(session.wait_for_text(WAITING_TEXT), "reception not restarted after dismissing the error")
    expect(not session.screen_contains(CARD_LIST_LEGEND), "card list shown with no card")


def scenario_cancel_without_cards_restarts_reception(session):
    session.wait_for_text(WAITING_TEXT)
    session.press("b")
    session.tick(30)
    expect(session.screen_contains(WAITING_TEXT), "reception not restarted after cancelling")
    create_first_card(session, KEYS_A, KEYS_B)
    expect(list_names(session) == ["1"], f"unexpected card list: {list_names(session)}")
    expect(session.screen_contains("START=NEW SELECT=DEL"), "card list legend missing")
    expect(session.screen_contains("SIGNALS 01/30"), "signal usage counter missing on the card list")


def scenario_first_signal_asks_card_name_then_signal_name(session):
    create_first_card(session, KEYS_A, KEYS_AB)
    expect(session.remote.jingle_count == 1, "jingle did not play once after the first signal")
    open_card(session)
    expect(list_names(session) == ["12"], f"signal not saved in the new card: {list_names(session)}")
    expect(session.row_text(TITLE_ROW)[TITLE_COLUMN:TITLE_COLUMN + 1] == "1", "card name not shown as title")
    session.press("b")
    expect(session.wait_for_text(CARD_LIST_LEGEND), "B did not return to the card list")


def scenario_discarding_first_signal_restarts_reception(session):
    capture_signal(session, NAME_CARD_TITLE)
    session.press("start")
    expect(session.wait_for_text(DISCARD_CARD_TEXT), "discard confirmation not shown")
    expect(session.screen_contains("SIGNAL WILL BE LOST"), "discard warning missing")
    session.press("b")
    expect(session.wait_for_text(NAME_CARD_TITLE), "refusing the discard did not return to the keyboard")
    session.press("start")
    expect(session.wait_for_text(DISCARD_CARD_TEXT), "discard confirmation not shown the second time")
    session.press("a")
    expect(session.wait_for_text(WAITING_TEXT), "reception not restarted after discarding")
    expect(not session.screen_contains(CARD_LIST_LEGEND), "card list shown after discarding")


def scenario_card_and_signal_names_are_checked(session):
    create_first_card(session, KEYS_A, KEYS_AB)
    session.press("start")
    expect(session.wait_for_text(NAME_CARD_TITLE), "card naming not shown")
    session.press_sequence(KEYS_A)
    session.press("start")
    expect(session.wait_for_text("ERROR E05"), "duplicate card name not rejected")
    session.press("b")
    session.press_sequence(KEYS_SPACE)
    session.press("start")
    expect(session.wait_for_text("ERROR E04"), "blank card name not rejected")
    session.press("b")
    session.press("start")
    expect(session.wait_for_text(DISCARD_CARD_TEXT), "discard confirmation not shown for an empty card name")
    expect(session.screen_contains("NOTHING IS SAVED"), "empty card discard warning missing")
    session.press("a")
    expect(session.wait_for_text(CARD_LIST_LEGEND), "card list not shown after discarding the card")
    expect(list_names(session) == ["1"], f"cards changed: {list_names(session)}")
    open_card(session)
    add_signal_to_open_card(session, KEYS_AB)
    expect(session.wait_for_text("ERROR E13"), "duplicate signal name not rejected inside the card")
    session.press("b")
    session.press("b")
    session.press_sequence(KEYS_SPACE_AFTER_B)
    session.press("start")
    expect(session.wait_for_text("ERROR E04"), "blank signal name not rejected")


def scenario_empty_card_and_signals_in_cards(session):
    create_first_card(session, KEYS_A, KEYS_AB)
    add_empty_card(session, KEYS_AB)
    expect(list_names(session) == ["1", "12"], f"unexpected cards: {list_names(session)}")
    session.press("up")
    session.press("down")
    open_card(session)
    expect(session.screen_contains(EMPTY_CARD_TEXT), "empty card not announced")
    expect(session.screen_contains("PRESS START TO ADD"), "empty card hint missing")
    add_signal_to_open_card(session, KEYS_AB)
    expect(session.wait_for_text(SIGNAL_LIST_LEGEND), "signal list not shown after adding to an empty card")
    expect(list_names(session) == ["12"], f"same signal name must be allowed in another card: {list_names(session)}")
    session.press("b")
    expect(session.wait_for_text(CARD_LIST_LEGEND), "card list not shown")


def scenario_signal_delete_and_replay_persist(session):
    create_first_card(session, KEYS_A, KEYS_AB)
    open_card(session)
    add_signal_to_open_card(session, KEYS_A)
    expect(session.wait_for_text(SIGNAL_LIST_LEGEND), "signal list not shown after the second signal")
    expect(list_names(session) == ["12", "1"], f"unexpected signals: {list_names(session)}")
    session.power_cycle()
    expect(session.wait_for_text(CARD_LIST_LEGEND), "card list not shown after the power cycle")
    open_card(session)
    expect(list_names(session) == ["12", "1"], f"signals lost across the power cycle: {list_names(session)}")
    session.press("up")
    session.press("down")
    session.press("down")
    session.remote.transmitted.clear()
    session.press("a")
    session.tick(REPLAY_WAIT_FRAMES)
    expected = pulse_levels()
    expected += [0] * (SAMPLE_COUNT - len(expected))
    expect(len(session.remote.transmitted) == SAMPLE_COUNT, f"replay sent {len(session.remote.transmitted)} samples")
    expect(session.remote.transmitted == expected, "replayed pulses differ from the recorded pulses")
    session.press("select")
    expect(session.wait_for_text(DELETE_SIGNAL_TEXT), "delete confirmation not shown")
    session.press("b")
    expect(session.wait_for_text(SIGNAL_LIST_LEGEND), "list not shown after refusing")
    expect(list_names(session) == ["12", "1"], "refused deletion changed the list")
    session.press("select")
    expect(session.wait_for_text(DELETE_SIGNAL_TEXT), "delete confirmation not shown the second time")
    session.press("a")
    expect(session.wait_for_text(SIGNAL_LIST_LEGEND), "list not shown after deleting")
    expect(list_names(session) == ["12"], f"signal not deleted: {list_names(session)}")
    expect(session.remote.deletion_jingle_count == 1, "deletion sound did not play after deleting a signal")
    session.power_cycle()
    expect(session.wait_for_text(CARD_LIST_LEGEND), "card list not shown after the second power cycle")
    open_card(session)
    expect(list_names(session) == ["12"], f"deletion not persistent: {list_names(session)}")
    session.press("select")
    expect(session.wait_for_text(DELETE_SIGNAL_TEXT), "delete confirmation not shown for the last signal")
    session.press("a")
    expect(session.wait_for_text(EMPTY_CARD_TEXT), "card not shown empty after deleting its last signal")


def scenario_card_deletion_needs_two_confirmations(session):
    create_first_card(session, KEYS_A, KEYS_AB)
    add_empty_card(session, KEYS_AB)
    session.press("select")
    expect(session.wait_for_text(DELETE_CARD_TEXT), "first warning not shown")
    expect(session.screen_contains("THIS ALSO DELETES"), "first warning does not mention the signals")
    expect(session.screen_contains("ALL ITS SIGNALS"), "first warning text incomplete")
    session.press("b")
    expect(session.wait_for_text(CARD_LIST_LEGEND), "B at the first warning did not cancel")
    expect(list_names(session) == ["1", "12"], "cancelled deletion changed the cards")
    session.press("select")
    expect(session.wait_for_text(DELETE_CARD_TEXT), "first warning not shown the second time")
    session.press("a")
    expect(session.wait_for_text(DELETE_CARD_SURE_TEXT), "second confirmation not shown")
    session.press("b")
    expect(session.wait_for_text(CARD_LIST_LEGEND), "B at the second confirmation did not cancel")
    expect(list_names(session) == ["1", "12"], "cancelled second confirmation changed the cards")
    session.press("select")
    expect(session.wait_for_text(DELETE_CARD_TEXT), "first warning not shown the third time")
    session.press("a")
    expect(session.wait_for_text(DELETE_CARD_SURE_TEXT), "second confirmation not shown the second time")
    session.press("a")
    expect(session.wait_for_text(CARD_LIST_LEGEND), "card list not shown after deleting the card")
    expect(list_names(session) == ["12"], f"card not deleted: {list_names(session)}")
    expect(session.remote.deletion_jingle_count == 1, "deletion sound did not play after deleting a card")
    session.power_cycle()
    expect(session.wait_for_text(CARD_LIST_LEGEND), "card list not shown after the power cycle")
    expect(list_names(session) == ["12"], f"deletion not persistent: {list_names(session)}")


def scenario_deleting_last_card_restarts_reception(session):
    create_first_card(session, KEYS_A, KEYS_B)
    session.press("select")
    expect(session.wait_for_text(DELETE_CARD_TEXT), "first warning not shown")
    session.press("a")
    expect(session.wait_for_text(DELETE_CARD_SURE_TEXT), "second confirmation not shown")
    session.press("a")
    expect(session.wait_for_text(WAITING_TEXT), "reception not started after deleting the last card")
    expect(not session.screen_contains(CARD_LIST_LEGEND), "card list shown with no card")


def scenario_card_deletion_removes_its_signals(session):
    create_first_card(session, KEYS_A, KEYS_AB)
    add_empty_card(session, KEYS_AB)
    session.press("select")
    session.wait_for_text(DELETE_CARD_TEXT)
    session.press("a")
    session.wait_for_text(DELETE_CARD_SURE_TEXT)
    session.press("a")
    expect(session.wait_for_text(CARD_LIST_LEGEND), "card list not shown")
    add_empty_card(session, KEYS_A)
    open_card(session)
    expect(session.screen_contains(EMPTY_CARD_TEXT), "a new card inherited signals of a deleted card")


def scenario_sram_diagnostic_survives_power_cycle(session):
    session.power_cycle(held_buttons=["select"])
    expect(session.wait_for_text("SRAM TEST"), "diagnostic menu not shown with SELECT held at boot")
    expect(session.screen_contains("SRAM BANKS: 16/16"), "bank count not shown in the diagnostic menu")
    session.press("a")
    expect(session.wait_for_text("ALL BANKS OK"), "immediate verification after the write did not pass")
    expect(session.screen_contains("BANK 15 OK"), "last bank not reported OK")
    session.press("a")
    session.power_cycle(held_buttons=["select"])
    expect(session.wait_for_text("SRAM TEST"), "diagnostic menu not shown after the power cycle")
    session.press("start")
    expect(session.wait_for_text("ALL BANKS OK"), "pattern not intact after the power cycle")
    session.press("a")
    expect(session.wait_for_text("B=EXIT"), "diagnostic menu not shown after the verification")
    session.press("b")
    expect(session.wait_for_text(WAITING_TEXT), "application did not start after leaving the diagnostic")


def corrupted_directory_patches(wiped_marker_bank=None):
    entry = bytes([USED_ENTRY_STATUS, 1]) + bytes(NAME_LENGTH - 1)
    patches = {}
    for copy_offset in (0, DIRECTORY_BACKUP_OFFSET):
        patches[copy_offset] = DIRECTORY_SIGNATURE + entry
        patches[copy_offset + DIRECTORY_SIZE_BYTES - 1] = bytes([0])
    if wiped_marker_bank is not None:
        patches[wiped_marker_bank * RAM_BANK_SIZE_BYTES + PROBE_OFFSET_IN_BANK] = bytes([0])
    return patches


def scenario_corrupted_directory_reports_sram_probe(session):
    session.power_cycle(ram_patches=corrupted_directory_patches())
    expect(session.wait_for_text("ERROR E08"), "error E08 not shown for a corrupted directory with cards")
    expect(session.screen_contains("SRAM BANKS: 16/16"), "bank probe result not shown")
    expect(session.screen_contains("SRAM KEPT: YES"), "kept result not YES with markers intact")
    session.press("a")
    expect(session.wait_for_text(WAITING_TEXT), "reception not started after the error")
    session.power_cycle(ram_patches=corrupted_directory_patches(wiped_marker_bank=WIPED_MARKER_BANK))
    expect(session.wait_for_text("ERROR E08"), "error E08 not shown the second time")
    expect(session.screen_contains("SRAM KEPT: NO"), "kept result not NO with a wiped marker")


def scenario_event_log_records_boots_and_saves(session):
    create_first_card(session, KEYS_A, KEYS_AB)
    session.power_cycle()
    expect(session.wait_for_text(CARD_LIST_LEGEND), "card list not shown after the power cycle")
    session.power_cycle()
    decoded = decode_log(session.read_ram())
    expect(decoded is not None, "event log not found in the save file")
    expect(decoded["boot_counter"] >= 2, f"boot counter not counting: {decoded['boot_counter']}")
    first_boot = [entry for entry in decoded["entries"] if entry["boot"] == 1]
    second_boot = [entry for entry in decoded["entries"] if entry["boot"] == 2]
    expect(any(entry["type"] == "SAVE" and entry["argument"] == 3 for entry in first_boot), "card and signal save not logged")
    expect(any(entry["type"] == "PROBE" and "not kept" in entry["detail"] for entry in first_boot), "first boot probe not logged as not kept")
    expect(any(entry["type"] == "PROBE" and "SRAM kept" in entry["detail"] and "not kept" not in entry["detail"] for entry in second_boot), "second boot probe not logged as kept")
    expect(any(entry["type"] == "MOUNT" and "primary valid" in entry["detail"] for entry in second_boot), "second boot mount not logged as valid")


def scenario_errors_are_logged(session):
    session.wait_for_text(WAITING_TEXT)
    session.remote.arm(QUIET_LEVELS)
    expect(session.wait_for_text("ERROR E03"), "error E03 not displayed")
    session.remote.disarm()
    session.press("a")
    session.power_cycle()
    decoded = decode_log(session.read_ram())
    expect(any(entry["type"] == "ERROR" and entry["argument"] == 3 for entry in decoded["entries"]), "error E03 not logged")


def build_directory_patches(cards, signals):
    image = bytearray(DIRECTORY_SIZE_BYTES)
    image[:len(DIRECTORY_SIGNATURE)] = DIRECTORY_SIGNATURE
    for index, glyph in cards:
        offset = len(DIRECTORY_SIGNATURE) + index * CARD_ENTRY_SIZE
        image[offset] = USED_ENTRY_STATUS
        image[offset + 1] = glyph
    signals_offset = len(DIRECTORY_SIGNATURE) + CARD_COUNT * CARD_ENTRY_SIZE
    for slot, card, glyph in signals:
        offset = signals_offset + slot * SIGNAL_ENTRY_SIZE
        image[offset] = USED_ENTRY_STATUS
        image[offset + 1] = card
        image[offset + 2] = glyph
    image[-1] = (CHECKSUM_SEED + sum(image[:-1])) & 0xFF
    return {0: bytes(image), DIRECTORY_BACKUP_OFFSET: bytes(image)}


def scenario_card_list_full_explains_the_limit(session):
    cards = [(index, 1 + index % 26) for index in range(CARD_COUNT)]
    session.power_cycle(ram_patches=build_directory_patches(cards, []))
    expect(session.wait_for_text(CARD_LIST_LEGEND), "card list not shown with 32 cards")
    session.press("start")
    expect(session.wait_for_text("ERROR E09"), "error E09 not shown with 32 cards")
    expect(session.screen_contains("TOO MANY CARDS"), "card limit message missing")
    expect(session.screen_contains("32 CARDS AT MOST"), "card limit number missing")
    expect(session.screen_contains("DELETE ONE FIRST"), "card limit advice missing")


def scenario_full_card_explains_the_limit(session):
    signals = [(slot, 0, 1 + slot) for slot in range(SIGNALS_PER_CARD)]
    session.power_cycle(ram_patches=build_directory_patches([(0, 1)], signals))
    expect(session.wait_for_text(CARD_LIST_LEGEND), "card list not shown")
    open_card(session)
    session.press("start")
    expect(session.wait_for_text("ERROR E10"), "error E10 not shown for a full card")
    expect(session.screen_contains("THE CARD IS FULL"), "full card message missing")
    expect(session.screen_contains("8 SIGNALS AT MOST"), "signal limit number missing")


def scenario_full_storage_explains_the_slots(session):
    cards = [(index, 1 + index) for index in range(FIVE_CARDS)]
    signals = [(slot, slot // SIGNALS_PER_CARD, 1 + slot % 26) for slot in range(SIGNAL_SLOTS)]
    session.power_cycle(ram_patches=build_directory_patches(cards, signals))
    expect(session.wait_for_text(CARD_LIST_LEGEND), "card list not shown")
    expect(session.screen_contains("SIGNALS 30/30"), "usage counter not showing a full storage")
    session.press_sequence(["down", "down", "down", "down"])
    open_card(session)
    expect(session.screen_contains(EMPTY_CARD_TEXT), "fifth card is not empty")
    session.press("start")
    expect(session.wait_for_text("ERROR E02"), "error E02 not shown with every slot used")
    expect(session.screen_contains("ALL 30 SIGNAL SLOTS"), "slot count missing in the message")
    expect(session.screen_contains("ARE IN USE"), "storage message missing")
    expect(session.screen_contains("SRAM BANKS: 16/16"), "SRAM size missing in the message")


def scenario_normal_boot_skips_diagnostic(session):
    expect(session.wait_for_text(WAITING_TEXT), "reception not shown on a normal boot")
    expect(not session.screen_contains("SRAM TEST"), "diagnostic shown without SELECT held")


def open_debug_screen(session):
    session.press("b")
    expect(session.wait_for_text("DEBUG"), "debug screen not shown with B on the card list")


def scenario_debug_screen_shows_the_system_state(session):
    create_first_card(session, KEYS_A, KEYS_AB)
    open_debug_screen(session)
    expect(session.screen_contains("BOOT 00001"), "boot counter missing")
    expect(session.screen_contains("SPEED NORMAL"), "CPU speed missing")
    expect(session.screen_contains("SRAM BANKS: 16/16"), "SRAM banks missing")
    expect(session.screen_contains("SRAM KEPT: NO"), "SRAM kept status missing")
    expect(session.screen_contains("SIGNALS 01/30"), "signal usage missing")
    expect(session.screen_contains("CARDS 01/32"), "card usage missing")
    expect(session.screen_contains("DIR 00030/00779"), "directory bytes in use missing")
    expect(session.screen_contains("PRIMARY: BLANK"), "primary copy status missing")
    expect(session.screen_contains("BACKUP: BLANK"), "backup copy status missing")
    expect(session.screen_contains("LAST ERROR: NONE"), "last error missing")
    session.press("b")
    expect(session.wait_for_text(CARD_LIST_LEGEND), "B did not leave the debug screen")


def scenario_debug_screen_counts_boots_and_shows_the_kept_sram(session):
    create_first_card(session, KEYS_A, KEYS_AB)
    session.power_cycle()
    expect(session.wait_for_text(CARD_LIST_LEGEND), "card list not shown after the power cycle")
    open_debug_screen(session)
    expect(session.screen_contains("BOOT 00002"), "boot counter did not advance")
    expect(session.screen_contains("SRAM KEPT: YES"), "kept SRAM not shown")
    expect(session.screen_contains("PRIMARY: VALID"), "valid primary copy not shown")
    expect(session.screen_contains("BACKUP: NOT CHECKED"), "unchecked backup copy not shown")


def scenario_debug_screen_lists_the_signals_of_every_card(session):
    create_first_card(session, KEYS_A, KEYS_AB)
    add_empty_card(session, KEYS_AB)
    open_debug_screen(session)
    session.press("a")
    expect(session.wait_for_text("SIGNALS PER CARD"), "cards page not shown")
    expect(session.screen_contains("00:1"), "first card count missing")
    expect(session.screen_contains("01:0"), "second card count missing")
    expect(session.screen_contains("02:-"), "unused card marker missing")
    expect(session.screen_contains("31:-"), "last card marker missing")
    session.press("a")
    expect(session.wait_for_text("BOOT 00001"), "A did not return to the system page")


def scenario_debug_screen_shows_the_last_error(session):
    create_first_card(session, KEYS_A, KEYS_AB)
    open_card(session)
    session.press("start")
    session.wait_for_text(WAITING_TEXT)
    session.remote.arm(QUIET_LEVELS)
    expect(session.wait_for_text("ERROR E03"), "error E03 not displayed")
    session.remote.disarm()
    session.press("a")
    expect(session.wait_for_text(SIGNAL_LIST_LEGEND), "signal list not shown after the error")
    session.press("b")
    expect(session.wait_for_text(CARD_LIST_LEGEND), "card list not shown")
    open_debug_screen(session)
    expect(session.screen_contains("LAST ERROR: E03"), "last error not shown in the debug screen")


DEBUG_SCENARIOS = [
    scenario_debug_screen_shows_the_system_state,
    scenario_debug_screen_counts_boots_and_shows_the_kept_sram,
    scenario_debug_screen_lists_the_signals_of_every_card,
    scenario_debug_screen_shows_the_last_error,
]


SCENARIOS = [
    scenario_first_launch_enters_reception,
    scenario_quiet_signal_reports_error_three,
    scenario_cancel_without_cards_restarts_reception,
    scenario_first_signal_asks_card_name_then_signal_name,
    scenario_discarding_first_signal_restarts_reception,
    scenario_card_and_signal_names_are_checked,
    scenario_empty_card_and_signals_in_cards,
    scenario_signal_delete_and_replay_persist,
    scenario_card_deletion_needs_two_confirmations,
    scenario_deleting_last_card_restarts_reception,
    scenario_card_deletion_removes_its_signals,
    scenario_corrupted_directory_reports_sram_probe,
    scenario_sram_diagnostic_survives_power_cycle,
    scenario_event_log_records_boots_and_saves,
    scenario_errors_are_logged,
    scenario_card_list_full_explains_the_limit,
    scenario_full_card_explains_the_limit,
    scenario_full_storage_explains_the_slots,
    scenario_normal_boot_skips_diagnostic,
]


def run_scenario(scenario, rom_path, symbol_path, recorder):
    session = Session(rom_path, symbol_path, coverage=recorder)
    try:
        session.start()
        scenario(session)
        return None
    except AssertionError as failure:
        return str(failure)
    except Exception:
        return traceback.format_exc()
    finally:
        session.close()


def parse_arguments(arguments):
    parser = argparse.ArgumentParser()
    parser.add_argument("rom")
    parser.add_argument("symbols")
    parser.add_argument("--map")
    parser.add_argument("--coverage-output")
    parser.add_argument("--debug", action="store_true")
    return parser.parse_args(arguments)


def main(arguments):
    options = parse_arguments(arguments)
    scenarios = DEBUG_SCENARIOS if options.debug else SCENARIOS
    recorder = None
    if options.coverage_output:
        labels = load_code_labels(options.map, excluded_section_names("."))
        recorder = CoverageRecorder(labels)
    failures = 0
    for scenario in scenarios:
        failure = run_scenario(scenario, options.rom, options.symbols, recorder)
        name = scenario.__name__
        if failure is None:
            print(f"PASS  {name}")
        else:
            failures += 1
            print(f"FAIL  {name}  {failure}")
    print(f"\n{len(scenarios) - failures} passed, {failures} failed, {len(scenarios)} total")
    if recorder:
        recorder.save(options.coverage_output, {"passed": len(scenarios) - failures, "total": len(scenarios)})
    return EXIT_FAILURE if failures else EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
