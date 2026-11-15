import json
import sys
from pathlib import Path

EXIT_SUCCESS = 0
EXIT_USAGE = 2
COLOR_GREEN = "44cc11"
COLOR_YELLOW_GREEN = "a4a61d"
COLOR_ORANGE = "fe7d37"
COLOR_RED = "e05d44"
THRESHOLD_GOOD = 85.0
THRESHOLD_FAIR = 70.0
THRESHOLD_LOW = 50.0


def coverage_color(value):
    if value >= THRESHOLD_GOOD:
        return COLOR_GREEN
    if value >= THRESHOLD_FAIR:
        return COLOR_YELLOW_GREEN
    if value >= THRESHOLD_LOW:
        return COLOR_ORANGE
    return COLOR_RED


def suite_color(result):
    return COLOR_GREEN if result["passed"] == result["total"] else COLOR_RED


def suite_status(result):
    return f"{result['passed']}/{result['total']} passed"


def badge_outputs(summary):
    outputs = {
        "coverage_status": f"{summary['label_coverage']:.1f}%",
        "coverage_color": coverage_color(summary["label_coverage"]),
    }
    for suite in ("unit", "flow", "debug"):
        outputs[f"{suite}_status"] = suite_status(summary[suite])
        outputs[f"{suite}_color"] = suite_color(summary[suite])
    return outputs


def main(arguments):
    if len(arguments) != 1:
        print("usage: badge_outputs.py <summary_file>")
        return EXIT_USAGE
    summary = json.loads(Path(arguments[0]).read_text())
    for key, value in badge_outputs(summary).items():
        print(f"{key}={value}")
    return EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
