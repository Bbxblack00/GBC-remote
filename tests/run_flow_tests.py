import sys
import traceback

from flow_harness import SAMPLE_COUNT, Session, build_pulse_levels

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_USAGE = 2
PULSE_WIDTH_SAMPLES = 3
PULSE_COUNT = 40
REPLAY_WAIT_FRAMES = 30
QUIET_LEVELS = [0] * 64
LIST_TITLE = "SIGNALS"
NAME_TITLE = "NAME THE SIGNAL"
WAITING_TEXT = "WAITING FOR SIGNAL"
DELETE_TEXT = "DELETE SIGNAL?"
DISCARD_TEXT = "DISCARD SIGNAL?"
LIST_FIRST_ROW = 2
LIST_NAME_COLUMN = 3
NAME_LENGTH = 8
INLINE_ERROR_ROW = 5
ERROR_SCREEN_ROW = 6


def expect(condition, message):
    if not condition:
        raise AssertionError(message)


def list_names(session):
    names = []
    for row in range(LIST_FIRST_ROW, LIST_FIRST_ROW + 8):
        text = session.row_text(row)[LIST_NAME_COLUMN:LIST_NAME_COLUMN + NAME_LENGTH].strip()
        if text:
            names.append(text)
    return names


def record_signal_until_naming(session):
    session.wait_for_text(WAITING_TEXT)
    session.remote.arm(build_pulse_levels(PULSE_WIDTH_SAMPLES, PULSE_COUNT))
    expect(session.wait_for_text(NAME_TITLE), "naming screen never appeared after capture")
    session.remote.disarm()


def type_name(session, buttons):
    session.press_sequence(buttons)


def scenario_first_launch_enters_reception(session):
    expect(session.wait_for_text(WAITING_TEXT), "reception screen not shown on first launch")


def scenario_quiet_signal_reports_error_three(session):
    session.wait_for_text(WAITING_TEXT)
    session.remote.arm(QUIET_LEVELS)
    expect(session.wait_for_text("ERROR E03"), "error E03 not displayed for a quiet capture")
    session.remote.disarm()
    session.press("a")
    expect(session.wait_for_text(WAITING_TEXT), "reception not restarted after dismissing the error")
    expect(not session.screen_contains(LIST_TITLE), "empty list shown after the error")


def scenario_cancel_without_signals_restarts_reception(session):
    session.wait_for_text(WAITING_TEXT)
    session.press("b")
    session.emulator.tick(30, False)
    expect(session.screen_contains(WAITING_TEXT), "reception not restarted after cancelling")
    expect(not session.screen_contains(LIST_TITLE), "empty list shown after cancelling")
    record_signal_until_naming(session)
    type_name(session, ["a"])
    session.press("start")
    expect(session.wait_for_text(LIST_TITLE), "list not shown after saving following a cancel")
    expect(session.wait_for_text("A=OK B=BACK"), "legend first line missing")
    expect(session.wait_for_text("START=NEW SELECT=DEL"), "legend second line missing")
    expect(list_names(session) == ["A"], f"unexpected list: {list_names(session)}")


def scenario_deleting_last_signal_restarts_reception(session):
    record_signal_until_naming(session)
    type_name(session, ["a"])
    session.press("start")
    expect(session.wait_for_text(LIST_TITLE), "list not shown after saving")
    session.press("select")
    expect(session.wait_for_text(DELETE_TEXT), "delete confirmation not shown")
    session.press("a")
    expect(session.wait_for_text(WAITING_TEXT), "reception not started after deleting the last signal")
    expect(not session.screen_contains(LIST_TITLE), "empty list shown after deleting the last signal")


def scenario_discarding_first_signal_restarts_reception(session):
    record_signal_until_naming(session)
    session.press("start")
    expect(session.wait_for_text(DISCARD_TEXT), "discard confirmation not shown")
    session.press("a")
    expect(session.wait_for_text(WAITING_TEXT), "reception not restarted after discarding the first signal")
    expect(not session.screen_contains(LIST_TITLE), "empty list shown after discarding")


def scenario_full_lifecycle(session):
    record_signal_until_naming(session)
    expect(session.remote.jingle_count == 0, "jingle played before the signal was saved")
    type_name(session, ["a", "right", "a"])
    session.press("start")
    expect(session.wait_for_text(LIST_TITLE), "list not shown after saving")
    expect(list_names(session) == ["AB"], f"unexpected list after first save: {list_names(session)}")
    expect(session.remote.jingle_count == 1, "jingle did not play exactly once")

    session.press("start")
    record_signal_until_naming(session)
    type_name(session, ["a", "right", "a"])
    session.press("start")
    expect(session.wait_for_text("ERROR E05"), "duplicate name was not rejected with E05")
    session.press("b")
    session.press("start")
    expect(session.wait_for_text(LIST_TITLE), "list not shown after second save")
    expect(list_names(session) == ["AB", "A"], f"unexpected list after second save: {list_names(session)}")

    session.press("start")
    record_signal_until_naming(session)
    type_name(session, ["left", "a"])
    session.press("start")
    expect(session.wait_for_text("ERROR E04"), "blank name was not rejected with E04")
    session.press("b")
    session.press("start")
    expect(session.wait_for_text(DISCARD_TEXT), "discard confirmation not shown for an empty name")
    expect(session.wait_for_text("A=YES: DISCARD"), "discard legend first line missing")
    expect(session.wait_for_text("B=NO: KEEP EDITING"), "discard legend second line missing")
    session.press("b")
    expect(session.wait_for_text(NAME_TITLE), "refusing the discard did not return to the keyboard")
    session.press("start")
    expect(session.wait_for_text(DISCARD_TEXT), "discard confirmation not shown the second time")
    session.press("a")
    expect(session.wait_for_text(LIST_TITLE), "confirming the discard did not return to the list")
    expect(list_names(session) == ["AB", "A"], "discarded naming changed the list")

    session.press("select")
    expect(session.wait_for_text(DELETE_TEXT), "delete confirmation not shown")
    session.press("b")
    expect(session.wait_for_text(LIST_TITLE), "list not shown after refusing deletion")
    expect(list_names(session) == ["AB", "A"], "refused deletion still changed the list")

    session.power_cycle()
    expect(session.wait_for_text(LIST_TITLE), "stored signals not shown after power cycle")
    expect(list_names(session) == ["AB", "A"], f"stored signals lost across power cycle: {list_names(session)}")

    session.press("down")
    session.remote.transmitted.clear()
    session.press("a")
    session.emulator.tick(REPLAY_WAIT_FRAMES, False)
    transmitted = session.remote.transmitted
    expected_levels = build_pulse_levels(PULSE_WIDTH_SAMPLES, PULSE_COUNT)
    expected_levels += [0] * (SAMPLE_COUNT - len(expected_levels))
    expect(len(transmitted) == SAMPLE_COUNT, f"replay sent {len(transmitted)} samples")
    expect(transmitted == expected_levels, "replayed pulses differ from the recorded pulses")

    session.press("up")
    session.press("select")
    expect(session.wait_for_text(DELETE_TEXT), "delete confirmation not shown for the second time")
    expect(session.row_text(7)[6:6 + NAME_LENGTH].strip() == "AB", "confirmation does not show the signal name")
    session.press("a")
    expect(session.wait_for_text(LIST_TITLE), "list not shown after confirming deletion")
    expect(list_names(session) == ["A"], f"signal not deleted: {list_names(session)}")

    session.power_cycle()
    expect(session.wait_for_text(LIST_TITLE), "list not shown after power cycle following deletion")
    expect(list_names(session) == ["A"], f"deletion not persistent: {list_names(session)}")


SCENARIOS = [
    scenario_first_launch_enters_reception,
    scenario_quiet_signal_reports_error_three,
    scenario_cancel_without_signals_restarts_reception,
    scenario_deleting_last_signal_restarts_reception,
    scenario_discarding_first_signal_restarts_reception,
    scenario_full_lifecycle,
]


def run_scenario(scenario, rom_path, symbol_path):
    session = Session(rom_path, symbol_path)
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


def main(arguments):
    if len(arguments) != 2:
        print("usage: run_flow_tests.py <rom> <symbols>")
        return EXIT_USAGE
    rom_path, symbol_path = arguments
    failures = 0
    for scenario in SCENARIOS:
        failure = run_scenario(scenario, rom_path, symbol_path)
        name = scenario.__name__
        if failure is None:
            print(f"PASS  {name}")
        else:
            failures += 1
            print(f"FAIL  {name}  {failure}")
    print(f"\n{len(SCENARIOS) - failures} passed, {failures} failed, {len(SCENARIOS)} total")
    return EXIT_FAILURE if failures else EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
