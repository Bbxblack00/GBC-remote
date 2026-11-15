# Debug build and event log

This file explains the two tools built to find out what the program and the flashcart really do: the **debug build** with its screen, and the **event log** saved in the SRAM. Technical details of the formats are in `TECHNICAL.md` (sections 4.8 and 10).

## Index

1. [Why these tools exist](#1-why-these-tools-exist)
2. [The debug build](#2-the-debug-build)
3. [The debug screen](#3-the-debug-screen)
4. [The event log](#4-the-event-log)
5. [Reading the log on a PC](#5-reading-the-log-on-a-pc)
6. [How to answer "does the SRAM survive a power-off?"](#6-how-to-answer-does-the-sram-survive-a-power-off)
7. [Tests](#7-tests)

## 1. Why these tools exist

The open problem is whether the data kept in the cartridge SRAM survives a power-off on the flashcart in use. Without a logic analyzer, and with no way to read the SRAM from the console itself, the program must show its own state and record its own history.

There is a limit: the Game Boy has no non-volatile memory other than the SRAM. The event log lives in the SRAM, so it survives only as much as the SRAM survives. It cannot judge the SRAM through a more reliable channel. What it gives is direct evidence: if after a power-off the log still holds the entries of the previous boot, the SRAM was kept.

## 2. The debug build

```
make DEBUG=1
```

The ROM is `build/debug/gbc-remote.gbc`. The normal ROM `build/gbc-remote.gbc` is untouched and does not contain the debug screen: the debug code is assembled only when `DEBUG_BUILD` is defined. The debug build combines with the SRAM size: `make DEBUG=1 SRAM_KB=32` builds `build/debug/sram-32kb/gbc-remote.gbc`.

In the debug build the legend of the card list reads `A=OPEN B=DEBUG`, and **B opens the debug screen**.

## 3. The debug screen

Two pages. **A** switches page, **B** goes back to the card list.

### Page 1: system state

| Line | Meaning |
|---|---|
| `BOOT nnnnn` | how many times the program started since the log was created. If it goes back to 1 after a power-off, the SRAM was not kept |
| `SPEED NORMAL` or `SPEED DOUBLE` | the CPU speed right now. The program should be at normal speed here |
| `SRAM BANKS: nn/16` | distinct SRAM banks measured at boot |
| `SRAM KEPT: YES/NO` | whether the probe markers of the previous boot were still there |
| `SIGNALS used/limit` | signals in use and the limit given by the SRAM |
| `CARDS used/32` | cards in use |
| `DIR used/779` | directory bytes in use over the directory size |
| `PRIMARY: ...` | state of the primary directory copy at mount: `VALID`, `BLANK`, `DAMAGED` |
| `BACKUP: ...` | state of the backup copy at mount. `NOT CHECKED` means the primary was valid and the backup was never read |
| `LAST ERROR: ...` | the last error shown since boot (`NONE` or `Enn`) |

### Page 2: signals per card

A grid of 32 cells `nn:s`: `nn` is the card index, `s` is the number of signals it holds (0 to 8). A card that does not exist shows `-`.

## 4. The event log

A circular buffer of 254 entries in the SRAM, in the first half of bank 0, at `$A800` (1024 bytes, see `TECHNICAL.md`, section 4.8). It is part of the normal ROM as well as the debug build.

What it records:

| Event | When | What the argument tells |
|---|---|---|
| `BOOT` | at every start | SRAM banks measured |
| `PROBE` | at every start | banks, and whether the SRAM was kept |
| `MOUNT` | after the directory is mounted | state of the primary and backup copy |
| `ERROR` | when an error is shown | the error code |
| `SAVE` | after a successful change | card created, signal saved, card and signal saved, signal deleted, card deleted |

Every entry also carries the boot counter, so entries can be grouped by boot.

The log is written at normal speed and is never verified: a failed write is silent, because a log must never stop the program. If its signature is missing the log is created again, and the boot counter restarts from 1.

The SRAM diagnostic (SELECT at boot, then A) erases the log along with everything else.

## 5. Reading the log on a PC

1. On the flashcart menu, select the game, press B, and choose `Copy SRAM To File` (EverDrive GB system). It copies the SRAM into `/EDGB/SAVE/gbc-remote.srm`.
2. Copy that file to the PC.
3. Run the decoder:

```
python3 tools/decode_log.py gbc-remote.srm
```

Example output:

```
boots counted: 2
entries: 7

boot     1  BOOT   16 SRAM banks
boot     1  PROBE  16 banks, SRAM not kept
boot     1  MOUNT  primary unformatted, backup unformatted
boot     1  SAVE   card and signal saved
boot     2  BOOT   16 SRAM banks
boot     2  PROBE  16 banks, SRAM kept
boot     2  MOUNT  primary valid, backup not checked
```

If the file has no log, the decoder says so and exits with an error.

## 6. How to answer "does the SRAM survive a power-off?"

1. Run the program, save a card with a signal, wait at least 3 seconds, and power off.
2. Power on, start the program, and open the debug screen (debug build) or just use the program. Power off again.
3. Copy the SRAM into the `.srm` file and decode it.

How to read the result:

| What the log shows | Meaning |
|---|---|
| Entries of boot 1 are still there next to boot 2, and `PROBE ... SRAM kept` for boot 2 | The SRAM was kept between the two boots |
| Only entries of the last boot, and a boot counter of 1 | The SRAM was not kept, or the flashcart restored an older save |
| `MOUNT primary damaged, backup valid` | One directory copy was damaged and repaired from the other: bits are being lost or changed |
| `ERROR E08` | Both directory copies were damaged and the cards were lost |

If the flashcart reloads an old save at every start, the log shows `BOOT` entries from a much earlier boot and the counter does not advance. In that case use `Copy SRAM To File` right after power-on, before `Load And Start`, as described in `README.md`.

## 7. Tests

- **Unit tests** (`tests/cases/test_event_log.asm`): boot counting, appending an entry, wrap-around keeping the newest entries, the mount classes, and no overlap with the directory.
- **Tool tests** (`tests/run_tool_tests.py`): the decoder on synthetic images.
- **Flow tests** (`tests/run_flow_tests.py`): a real run, a power cycle, and the log decoded from the save file, checking the boot counter, the save event, and the kept/not kept result. Errors are logged too.
- **Debug flow tests** (`tests/run_flow_tests.py --debug`, on the debug ROM): the contents of both pages of the debug screen.

`make test` runs all of them. `make coverage` includes the debug ROM in the coverage count.
