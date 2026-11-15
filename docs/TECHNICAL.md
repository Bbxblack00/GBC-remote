# Technical documentation

This file holds the technical side of the project: memory, data formats, infrared timing, error handling, tests, and everything we discovered about the hardware. For how to use the program see `README.md`. For the debug build and the event log see `DEBUG.md`. For the development rules see `../AGENTS.md`.

Statements are labeled: **verified** (tried on the emulator or on a console), **hypothesis** (consistent with the data, not proven), **unknown**.

## Index

1. [Architecture](#1-architecture)
2. [Boot](#2-boot)
3. [Console memory (WRAM)](#3-console-memory-wram)
4. [Cartridge SRAM](#4-cartridge-sram)
5. [Infrared sampling](#5-infrared-sampling)
6. [CPU speed](#6-cpu-speed)
7. [Error handling](#7-error-handling)
8. [User interface](#8-user-interface)
9. [Audio](#9-audio)
10. [Build](#10-build)
11. [Tests](#11-tests)
12. [What we discovered about the hardware](#12-what-we-discovered-about-the-hardware)
13. [Limits and next steps](#13-limits-and-next-steps)
14. [Hardware used for testing](#14-hardware-used-for-testing)
15. [Test coverage](#15-test-coverage)
16. [References](#16-references)

## 1. Architecture

```
inc/            constants, register names, macros (no magic numbers in the code)
src/boot/       entry point and main
src/hal/        hardware access: clock, lcd, joypad, sram, infrared, audio, vram_text
src/lib/        generic memory helpers
src/logic/      application logic and screens
src/data/       tables only: font, strings, dialogs, palettes, keyboard, melodies, signatures
tests/          assembly framework, cases, Python runners, flow harness
.github/        the workflow that runs the tests and publishes the badges
tools/          command-line tools (event log decoder)
docs/           this documentation
```

Rules:
- Only `src/hal/` and `src/lib/` touch hardware registers.
- No comments in the code: the names explain the intent. This applies to the Makefile and to Python as well.
- Every piece of RAM state has exactly one owner module.

Main modules of `src/logic/`:

| Module | Job |
|---|---|
| `application` | main loop: card list, opening a card, actions |
| `storage` | directory, cards, signals, samples, unique names, repair |
| `event_log` | persistent event log in SRAM |
| `sram_probe` | measures the SRAM banks at every boot |
| `sram_diagnostic` | diagnostic opened with SELECT at boot |
| `debug_screen` | debug screen (debug build only) |
| `signal_capture` | waiting for and capturing the signal |
| `list_view` | scrolling list with cursor |
| `card_list_screen`, `signal_list_screen` | the list screens |
| `name_entry_screen`, `keyboard`, `name_buffer` | name entry |
| `confirm_dialog` | every confirmation, driven by descriptors in `src/data/dialogs.asm` |
| `workflow_*` | sequences: first signal, new signal, card, send, delete |
| `error_screen`, `error_handling` | errors |
| `jingle` | melodies |

## 2. Boot

Order in `src/boot/main.asm`:

1. Stack and `Clock_EnterNormalSpeed` (the console starts at normal speed).
2. `Lcd_Initialise`: LCD off, font loaded, maps cleared.
3. `SramProbe_Run`: measures the banks and computes the signal limit.
4. `EventLog_Initialise` and `EventLog_RecordBootFacts`: increment the boot counter and log the boot and the probe result.
5. If SELECT is held: `SramDiagnostic_Run`.
6. `Application_Run` → `Storage_Mount`, then `EventLog_RecordMountResult`.

WRAM is not initialized on real hardware: no routine may assume zero values at boot.

## 3. Console memory (WRAM)

| Area | Size | Owner |
|---|---|---|
| Stack | 64 bytes | `main` |
| Directory mirror | 779 bytes | `storage` |
| Name being edited (`wNameBuffer`) | 11 bytes | `name_buffer` |
| Names of the scrolling list | 32 × 11 = 352 bytes | `list_view` |
| Sample buffer (`$D000`–`$DEFF`) | 3840 bytes | `sample_buffer` |
| Boot counter, last error | 3 bytes | `event_log`, `application` |

The sample buffer lives in internal WRAM (`WRAMX`, bank 1). Infrared capture and replay read and write only this buffer, never the SRAM: on some flashcarts the SRAM may not tolerate double speed accesses (hypothesis, see section 12).

## 4. Cartridge SRAM

### 4.1 ROM header

`rgbfix -C` (GBC only), cartridge type `$1B` (MBC5 + RAM + battery), 32 KB ROM. The RAM size (`-r`) follows the Makefile variable `SRAM_KB`:

| `SRAM_KB` | Header code `$0149` | Banks |
|---|---|---|
| 8 | `$02` | 1 |
| 32 | `$03` | 4 |
| 64 | `$05` | 8 |
| 128 (default) | `$04` | 16 |

`SRAM_KB` also sets `SRAM_BANK_LIMIT`, a ceiling on the banks the program is allowed to use: the usable banks are `min(measured banks, SRAM_BANK_LIMIT)`. The ceiling lets us try small memories on the emulator, which always has 128 KB.

MBC5: RAM is enabled by writing `$0A` to `$0000`, and the bank (`$00`–`$0F`) is selected by writing to `$4000` [R2]. RAM sizes in the header (`$0149`): `$02` = 8 KiB, `$03` = 32 KiB, `$04` = 128 KiB [R3]. The flag `$0143` marks the ROM as GBC-only [R3]. `rgbfix` sets these bytes [R8]. The program enables the SRAM only for the duration of each access and disables it right after.

### 4.2 Halves of 4096 bytes

The SRAM is treated as halves of 4096 bytes (`$A000`–`$AFFF` and `$B000`–`$BFFF` of every bank).

- **First half of bank 0:** directory, event log, and reserved bytes (map below).
- **Every other half:** one signal. Signal `n` lives in half `n + 1`, that is in bank `(n + 1) / 2`, half `(n + 1) % 2`.

The maximum number of signals is `min(30, 2 × banks − 1)`, where `banks` is the number of distinct banks measured at boot. With 128 KB: 30. With 32 KB: 7. With 8 KB: 1.

Map of the first half of bank 0:

| Address | Size | Content |
|---|---|---|
| `$A000` | 779 | primary directory |
| `$A400` | 779 | backup directory |
| `$A800` | 1024 | event log |
| `$AC00`–`$AEFF` | 768 | free |
| `$AF00` | 1 | SRAM probe marker |
| `$AFFF` | 1 | integrity byte of the half (unused in bank 0) |

### 4.3 Directory

Size: 4 + 32 × 12 + 30 × 13 + 1 = **779 bytes**.

| Offset | Length | Content |
|---|---|---|
| 0 | 4 | signature `GBCR` (`47 42 43 52`) |
| 4 | 32 × 12 | card entries |
| 388 | 30 × 13 | signal entries |
| 778 | 1 | checksum |

Card entry (12 bytes): status (`$A5` = used, `$00` = free) + 11 name glyphs.
Signal entry (13 bytes): status + card index + 11 name glyphs.

Names are stored as font glyph indexes (A = 1, 0 = 27, space = 0), not as ASCII.

Checksum: `$C3` plus the sum of the previous 778 bytes, modulo 256.

**Two copies.** The directory is written twice in bank 0: the primary at `$A000` and a backup at `$A400`. Every write rewrites both and reads both back to verify them.

**Mounting** (`Storage_Mount`):

1. Reads the primary copy and classifies it: valid (right signature and checksum), unformatted (signature missing), or damaged (signature present, wrong checksum).
2. If valid: done. The backup class is recorded as "not checked".
3. Otherwise reads the backup copy. If it is valid, rewrites the primary and finishes silently.
4. If neither is valid: if at least one has the signature and holds used cards, reformats and reports E08. If it holds no cards, reformats silently. If neither has the signature it is the first launch: formats silently.

Status: **verified** on the emulator (tests `Test_Mount*`).

### 4.4 Samples

Every signal half contains:

- 15 pages of 256 bytes = **3840 bytes** of samples;
- a sixteenth reserved page. Its last byte (`base + $0FFF`) is the signature `$5A`.

A signal becomes "used" in the directory only after the names are confirmed and the directory is written and read back. A cancelled name leaves no residue. The sample, however, is already written in its half: it stays as unused data and is overwritten by the next recording in that slot.

The signature `$5A` detects a sample that was never written or is damaged (error E06).

### 4.5 SRAM probe

At every boot `SramProbe_Run` writes a marker byte at `$AF00` of each of the 16 banks (bank index XOR `$6B`). `$AF00` sits in the reserved page of the first half, so no directory or sample ever uses it.

Before writing, it checks whether the markers of the previous boot form a coherent pattern (the `SRAM KEPT` flag). After writing, it derives the number of distinct banks `N`:

- With `N` distinct banks, bank `k` shares its memory with bank `k mod N`. After writing the banks in order from 0 to 15, physical bank `j` holds the marker of bank `16 − N + j`.
- So `N = 16 − (index read in bank 0)`, accepted only if `N` is a power of two and all 16 banks are coherent.
- `N` is then clamped by `SRAM_BANK_LIMIT`, and the signal limit `2N − 1` (at most 30) follows.

The result appears in the diagnostic menu, on the debug screen, in the event log, and on the E01, E08 and E11 screens. **Verified** on the emulator with 8, 32, 64 and 128 KB.

### 4.6 Diagnostic

Holding SELECT at boot opens the menu. With A it writes a pattern in every bank (low byte of the address XOR `bank XOR $5C`) and reads it back at once. After a power-off, START reads the same pattern again. The probe byte (`$AF00`) and, in bank 0, the event log region are skipped. The diagnostic **erases** all saved data.

### 4.7 The doubt: do all signals end up on the same memory?

**The doubt.** The program assumes the SRAM is made of independent banks of 8 KB: the register at `$4000` chooses which bank appears in `$A000`–`$BFFF` [R2], and each signal sits in a different place. But the header only declares a size [R3]; the flashcart may have less SRAM and ignore the high bits of the bank register. In that case bank `k` is the same as bank `k mod N`, where `N` is the number of real banks: every bank points to the **same physical memory** ("a single line of memory") and signals and directory overwrite each other.

**Why it could not be excluded in advance.** The code writes and reads back at once, and the read-back succeeds anyway: the byte just written is there, even if it erased another one. The only way to know is to measure it. PyBoy always has 128 KB of distinct SRAM, so emulator tests cannot see it on their own.

**Effect, by number of real banks:**

| Real banks `N` | Memory | What happens | Possible signals |
|---|---|---|---|
| 16 | 128 KB | no overlap | 30 |
| 8 | 64 KB | banks 8–15 are copies of banks 0–7 | 15 |
| 4 | 32 KB | banks 4–15 are copies of banks 0–3: a signal beyond the seventh would land on the directory and on the others | 7 |
| 1 | 8 KB | every bank is the same: only two halves remain, the directory and one signal | 1 |

**What really happened.** With the 128 KB header the probe answered `ALIAS`. With the 32 KB header it measured 4 banks. Before the limit existed, capturing a signal in a "high" bank wrote 3840 bytes over the directory in SRAM: the directory was rewritten only if the name was confirmed, so a cancellation left it damaged. This is one probable cause of the wrong names and of E08. It is not proven as the only cause: see section 12.

**How we measure it** (section 4.5). At boot the probe writes a different marker in every bank and deduces `N` from the pattern that remains. If the pattern is coherent with no `N` (for example banks only partly distinct) it assumes `N = 1`, the cautious choice.

**What we did:**
- the maximum number of signals follows the SRAM found, `2 × N − 1`, at most 30;
- signal 0 uses the second half of bank 0, which used to stay empty;
- selectable header: `SRAM_KB` in the Makefile, because some flashcarts decide the SRAM from the header [R3];
- two copies of the directory and a checksum (section 4.3);
- the measurement is shown in the diagnostic menu, on the debug screen, and in the event log.

**What stays open:**
- if the SRAM found becomes smaller between two boots, signals beyond the new limit are no longer reachable: there is no check yet;
- with `N = 1` only one signal fits;
- to regain capacity on a small SRAM the signals would have to be compressed (section 13).

### 4.8 Event log

A persistent log of what the program did, kept in SRAM so it can be read on a PC. The format is a **reserved region**: nothing else may use it.

Region: `$A800`–`$ABFF` of bank 0 (1024 bytes).

| Offset | Length | Content |
|---|---|---|
| 0 | 4 | signature `GBLG` (`47 42 4C 47`) |
| 4 | 1 | write index (0 to 253) |
| 5 | 2 | boot counter, little endian |
| 7 | 1 | reserved |
| 8 | 254 × 4 | entries |

Entry (4 bytes): event type, argument, boot counter low byte, boot counter high byte. The log is circular: when it is full, the oldest entries are overwritten. An entry of type 0 is empty.

| Type | Event | Argument |
|---|---|---|
| 1 | boot | distinct SRAM banks |
| 2 | probe | bit 7 = SRAM kept, bits 0–6 = banks |
| 3 | mount | primary class in the high nibble, backup class in the low nibble (0 valid, 1 unformatted, 2 damaged, 3 not checked) |
| 4 | error | error code |
| 5 | save | 1 card created, 2 signal saved, 3 card and signal saved, 4 signal deleted, 5 card deleted |

The log is written at normal speed with the SRAM enabled only for the write, and it is never verified: a failed write must not stop the program. If the signature is missing the log is initialized.

The log keeps what the SRAM keeps. It cannot prove the SRAM persists through a channel more reliable than the SRAM itself, but it gives direct evidence: if after a power-off the log holds the entries of the previous boot, the SRAM was kept. `tools/decode_log.py` reads the log from a `.srm` file. See `DEBUG.md`.

## 5. Infrared sampling

### 5.1 The RP register (`$FF56`)

See [R1], entry `FF56 — RP`.

| Bit | Function |
|---|---|
| 0 | write: 1 = LED on |
| 1 | read: 0 = sensor lit |
| 6-7 | `11` enables reading |

The sensor does not demodulate: the samples already contain the carrier at about 38 kHz. For this reason replay does not generate the carrier but plays the samples back as they are.

### 5.2 Format

One sample per bit, 8 samples per byte, **1 = LED on**. The first sample ends in bit 0 of the byte. On capture the sensor is inverted (`cpl` on every byte). On replay `rr b` extracts bit 0 first.

### 5.3 Timing

All counts are in **machine cycles** (M-cycles, 4 clock cycles). An earlier estimate confused the two and was wrong by a factor of 4.

| Speed | M-cycle rate | M-cycle duration |
|---|---|---|
| normal | 1.048576 MHz | 0.954 µs |
| double speed | 2.097152 MHz | 0.477 µs |

Instruction cycle counts come from the RGBDS table [R7] (1 MHz, or 2 MHz in double speed).

Per sample: capture = `ldh a,[c]` (2) + `rra` (1) + `rra` (1) + `rr b` (2) + `nop` (1) = **7**. Replay = `rr b` (2) + `ld a,RP_...` (2) + `rla` (1) + `ldh [c],a` (2) = **7**.

Per byte: 8 × 7 + 9 of overhead = **65**. Capture: `ld a,b`, `cpl`, `ld [hli],a`, `ld a,h`, `cp e`, `jr nz` (4 + 5). Replay: `ld a,[hli]`, `ld b,a`, `nop`, `ld a,h`, `cp e`, `jr nz` (4 + 5).

Results:
- one sample every 7 M-cycles = **3.34 µs** at double speed (6.68 µs at normal speed);
- 3840 bytes × 65 M-cycles = 249,600 M-cycles = **119 ms** at double speed (238 ms at normal speed);
- an NEC frame lasts about 67 ms: it fits in the 119 ms;
- half period of a 38 kHz carrier: about 13 µs, that is about 4 samples: the resolution moves every edge by about 3 µs. A receiver with little tolerance might not recognize the signal.

**Rule:** capture and replay must have the same cadence. Whoever changes one loop must keep the other equal. The `nop` in capture and the per-byte `nop` in replay exist for this.

### 5.4 Validation

After capture the program counts the bytes that differ from the previous one. With fewer than 8 changes it reports E03 (noise, not a command).

### 5.5 History

The first version sampled one byte per sample for about 35 ms at double speed, less than an NEC frame: replay was not recognized. With packed samples and 119 ms replay works (**verified on a console**, before the cards feature).

## 6. CPU speed

The console runs at normal speed. Double speed is used only while capturing and sending infrared.

- `Clock_EnterNormalSpeed`: goes back to normal speed if it is in double speed.
- `Clock_EnterSignalSpeed`: goes to the infrared speed, that is `SELECTED_CPU_SPEED` (default double).

Speed switch: `di`, all joypad lines deselected, `IF` and `IE` cleared, `KEY1` written with bit 0 set, `stop` [R1]. After `stop` the CPU halts for 2050 M-cycles [R1], about 2 ms at normal speed. The joypad lines are described in [R4].

The write to `KEY1` keeps bit 7 (current speed) as read. On real hardware bit 7 is read-only and ignored on write [R1]. PyBoy 2.9.0 replaces the whole register on a write, which cleared bit 7 and made the program read a stale speed after switching back; keeping bit 7 makes both behave the same.

All SRAM access happens at normal speed. The signal is captured in the WRAM buffer at double speed and then copied into SRAM at normal speed.

## 7. Error handling

### 7.1 Mechanism

A routine that can fail returns a code in `A`, `0` for success. The macros in `inc/error_handling.inc`:

- `Try routine`: calls it, and if `A` is not zero returns at once with the same code;
- `Throw code`: loads the code and returns;
- `Succeed`: loads `ERROR_NONE` and returns.

`Application_Catch` records the error in the event log and shows it on screen as `ERROR Enn`, with a message in words and a pointer to this file (`SEE TECHNICAL.MD`). `ERROR_CANCELLED` (`$FF`) is not an error: it is not shown and has no code.

### 7.2 Error table

| Code | Constant | Name | What it means | What to do |
|---|---|---|---|---|
| E01 | `ERROR_DIRECTORY_VERIFY_FAILED` | Directory write not verified | The directory written to SRAM, read back, is different. The cartridge has no SRAM, the SRAM is disabled, or the write fails. | Use an MBC5 cartridge with SRAM. Check the flashcart save settings. |
| E02 | `ERROR_STORAGE_FULL` | Storage full | Every signal slot is used (30 with 128 KB, fewer with a smaller SRAM). | Delete a signal with SELECT, then record again. |
| E03 | `ERROR_SIGNAL_TOO_SHORT` | Signal too short | The sample has fewer than 8 changes: it is noise, not a command. | Move the remote closer to the sensor. Avoid sunlight and incandescent lamps. Retry. |
| E04 | `ERROR_NAME_EMPTY` | Empty name | The name is made only of spaces. With a completely empty name START gives no error: it opens the cancellation confirmation. | Type at least one character that is not a space. |
| E05 | `ERROR_CARD_NAME_IN_USE` | Card name in use | A card with that name already exists. | Choose a different name. |
| E06 | `ERROR_SIGNAL_DAMAGED` | Signal damaged | The saved sample has no integrity signature. | Delete the signal and record it again. |
| E07 | `ERROR_INVALID_CARD` | Invalid card index | Internal error: card index out of range. | Restart. If it repeats, report the problem. |
| E08 | `ERROR_DIRECTORY_CORRUPT` | Directory damaged | Neither directory copy has the right checksum, and at least one has the signature and holds cards. The program reformats it and the cards are lost. If the damaged directory was empty the repair is silent. | Run the SRAM diagnostic (README) to see whether the flashcart keeps data. |
| E09 | `ERROR_CARD_LIST_FULL` | Too many cards | There are already 32 cards. | Delete a card with SELECT, then create a new one. |
| E10 | `ERROR_CARD_FULL` | Card full | The card already has 8 signals. | Delete a signal of the card or use another card. |
| E11 | `ERROR_SAMPLE_VERIFY_FAILED` | Signal write not verified | The signal written to SRAM, read back, is different. | Same as E01. Check the SRAM size with the probe lines. |
| E12 | `ERROR_INVALID_SIGNAL` | Invalid signal index | Internal error: signal index out of range. | Restart. If it repeats, report the problem. |
| E13 | `ERROR_SIGNAL_NAME_IN_USE` | Signal name in use | A signal with that name already exists in the same card. | Choose a different name. |

E05, E13 and E04 appear under the name field instead of on the error screen.

Messages in words on the error screen:

| Code | Lines shown |
|---|---|
| E01 | `SRAM WRITE FAILED` / `THE DIRECTORY WAS` / `NOT SAVED` |
| E02 | `ALL nn SIGNAL SLOTS` / `ARE IN USE` / `SRAM BANKS: nn/16` (`nn` is the limit and the banks measured) |
| E03 | `SIGNAL TOO SHORT` / `MOVE THE REMOTE` / `CLOSER AND RETRY` |
| E06 | `SIGNAL IS DAMAGED` / `DELETE IT AND` / `RECORD IT AGAIN` |
| E07, E12 | `CARD NOT FOUND` or `SIGNAL NOT FOUND` / `RESTART THE` / `PROGRAM` |
| E08 | `DIRECTORY DAMAGED` / `THE CARDS WERE LOST` |
| E09 | `TOO MANY CARDS` / `32 CARDS AT MOST` / `DELETE ONE FIRST` |
| E10 | `THE CARD IS FULL` / `8 SIGNALS AT MOST` / `DELETE ONE FIRST` |
| E11 | `SRAM WRITE FAILED` / `THE SIGNAL WAS` / `NOT SAVED` |

### 7.3 The SRAM lines on E01, E08 and E11

Under the code, on the E01, E08 and E11 screens, the program shows two lines measured at boot by the probe (section 4.5):

| Line | Meaning |
|---|---|
| `SRAM BANKS: 16/16` | The 16 banks are distinct: the SRAM really is 128 KB. |
| `SRAM BANKS: 4/16` (or 1, 2, 8) | The SRAM is smaller than 128 KB: the banks overlap (section 4.7). The program limits the signals to the memory found. Also try the variant with the aligned header (README). |
| `SRAM KEPT: YES` | The markers written at the previous boot were still there: the SRAM was kept between two boots. |
| `SRAM KEPT: NO` | The markers were not there, or did not form a coherent pattern: first boot, or the flashcart restored an old save, or it never saved the SRAM. |

With `KEPT: YES` and E08 repeating, the defect is not in how the SRAM is kept.

The same two lines, `SRAM BANKS` and `SRAM KEPT`, appear in the diagnostic menu (SELECT held at boot) with no error needed.

## 8. User interface

- **Text:** 5×7 font in 8×8 tiles, 46 glyphs (capitals, digits, `= ? . - : > ! _ /`). Rows are stored at 1 bit per pixel in ROM and expanded to 2 bits at load time. Strings use an RGBDS `CHARMAP` and end with `$FF`.
- **VRAM writes:** only with the LCD off or in VBlank. The list cursor is updated in VBlank (fewer than about 1140 M-cycles available); when the list scrolls, the screen is redrawn with the LCD off.
- **Scrolling list:** 14 visible rows. The cursor column belongs to the list: no screen may write there.
- **Dialogs:** a 13-byte descriptor in ROM (question, detail line, two warnings, two legend lines, source of the name to show). `confirm_dialog` copies it to WRAM and shows it. A new confirmation is a new descriptor, not a new routine.
- **Keyboard:** 4 rows × 10 columns. The number row sits above the letters (QWERTY). The space key is the last one.
- **Themes:** four palettes (normal, reception, alert, sending) chosen in `Theme_Apply`.
- **Counter:** on the card list, in the title row, `SIGNALS used/limit`: the signals in use and the limit computed from the SRAM found.
- **Debug screen:** only in the debug build, opened with B on the card list. See `DEBUG.md`.

## 9. Audio

Channel 1 (square wave), registers `NR10`–`NR14`, master control `NR50`–`NR52` [R5]. Success melody: C5, E5, G5, C6. Deletion melody: G5, E5, C5, descending. Duration is counted in frames (waiting for VBlank). The frequency register values (`2048 − 131072 / f`) are in `inc/audio_notes.inc`.

## 10. Build

RGBDS 1.0 or later is required.

| Command | Result |
|---|---|
| `make` | `build/gbc-remote.gbc` |
| `make SRAM_KB=32` | `build/sram-32kb/gbc-remote.gbc`, header and bank ceiling for 32 KB. Values: 8, 32, 64, 128 |
| `make DEBUG=1` | `build/debug/gbc-remote.gbc`, with the debug screen. Combines with `SRAM_KB` |
| `make test` | builds and runs the whole suite (unit, flow, debug flow, SRAM sizes, tools) |
| `make coverage` | runs the suites with coverage measurement and regenerates `docs/COVERAGE.md` and the badges |
| `make RGBDS_DIR=/path/` | uses an RGBDS that is not in the `PATH` |
| `make CPU_SPEED=0` | infrared at normal speed (experiment only) |

Build flags are passed to RGBDS as `-D`: `SRAM_BANK_LIMIT`, `DEBUG_BUILD`, `SELECTED_CPU_SPEED`. Every variant has its own build directory, so no stale object is ever reused.

## 11. Tests

`make test` runs five levels, all on PyBoy without a window [R9] except the tool tests.

**Unit tests** (`tests/cases/`, 50) [R9]: a test ROM links the real routines. Every test returns `0` if it passes, otherwise the number of the failed assertion. The runner (`tests/run_tests.py`) finds the tests from the `.sym` file, runs the ROM until the end marker, and reads the results from WRAM. A test that never ran counts as failed.

**Flow tests** (`tests/run_flow_tests.py`, 19): start the real ROM, press the keys, and read the background map. The infrared sensor is simulated with hooks (`tests/flow_harness.py`):

- at the start of `Infrared_IsSignalDetected` it forces "light detected";
- in each of the 8 copies of the capture loop it forces the value read;
- in each of the 8 copies of the send loop it records the level written, to compare sending with recording.

The harness can also prepare the SRAM before boot (`ram_patches`) to simulate old or damaged data, and can read the save file after a power cycle.

**Debug flow tests** (`--debug`, 4): run on the debug build and check the debug screen: boot counter, speed, SRAM banks, usage, directory bytes, copy status, last error, and the signals per card.

**SRAM size tests** (`tests/run_size_tests.py`, 4): build the ROM for 8, 32, 64 and 128 KB, boot it, and check the banks measured and the signal limit.

**Tool tests** (`tests/run_tool_tests.py`, 10): check the event log decoder on synthetic images (wrong signature, chronological order, wrap-around, 16-bit counter, descriptions), and the badge values (coverage colors and the status text of passing and failing runs).

**Limits of the suite:** PyBoy does not emulate the infrared sensor, does not emulate flashcarts, and always has 128 KB of distinct SRAM. Overlapping banks are proven with synthetic patterns and with headers for 8, 32 and 64 KB, not with a real card.

To add a test: a routine in `tests/cases/`, registered in `tests/framework/test_table.asm` with `RegisterTest`. For a flow: a `scenario_...` function in `tests/run_flow_tests.py`, added to `SCENARIOS` (or to `DEBUG_SCENARIOS`).

## 12. What we discovered about the hardware

A chronology of the facts and their status.

1. **Capture too short** (verified on a console). The first capture lasted about 35 ms: replay was not recognized. With packed samples, 119 ms, replay works.
2. **Unit mistake** (fixed). Some early estimates counted M-cycles as clock cycles, getting times wrong by a factor of 4. Everything is now in M-cycles.
3. **Save not kept** (verified on a console). After a power-off wrong names and E08 appeared.
4. **SRAM smaller than declared** (verified on a console). With the 128 KB header the probe answered `ALIAS`: the banks overlapped. With the 32 KB header: `SRAM BANKS: 04/16`, that is 32 KB. With overlapping banks the program overwrote its own directory.
5. **The card is an EverDrive GB** (verified from the files). `GBOS.GB` has `KRKZ` (Krikzz) in its header. The menu contains `Load And Start`, `Load Only`, `RAM Size:`, `Save RAM:`, `Copy File To SRAM`, `Copy SRAM To File`, and saves go to `/EDGB/SAVE` as `.srm` files. The card says "EverDrive GB MAX"; the seller presents it as "Game Flash GB PRO (OS V4)". There is no manual.
6. **The extracted `.srm`** (verified) held two cards ("1", "2") and one signal ("QWERTY"), so the card does save. But it was an old save: the probe markers written by recent versions were missing. The computed checksum was `0xF5` and the stored one `0x75`: a difference of `0x80`, one byte `0x80` in the entry of signal 2 where there should have been `0`. **Unknown** whether the program or a flipped bit on the card wrote it.
7. **Hypothesis on the E08 cycle** (not proven). `Load And Start` reloads the `.srm` into the SRAM at every boot. If the writes of the previous session were never copied into the `.srm`, the program finds the old data again. The recommended procedure is to copy the SRAM into the file before relaunching: see `README.md`.
8. **After the two directory copies and the procedure with the card menu** (verified on a console) E08 no longer appears. **We do not know** whether the data really survives a power-off: to be verified. The event log (section 4.8) is meant to answer exactly this.
9. **PyBoy `KEY1` write** (verified). PyBoy 2.9.0 replaces the whole `KEY1` register on a write, losing bit 7. The program now preserves bit 7 (section 6). This is an emulator quirk; the original code was correct for real hardware [R1].

To reread the `.srm`: the first 4 bytes are the signature, then the entries as in 4.3. The extracted files are in `../file-scheda/`.

## 13. Limits and next steps

- **Never verified on a console:** the full operation of the cards feature, the debug build, the event log, and persistence after a power-off.
- **Low capacity with 32 KB:** 7 signals in total. Compressing the signals (durations of pulses and gaps plus the carrier period, about 150 bytes instead of 3840) would give hundreds of signals. Capture would stay raw and replay would use the same loop: compression would run at normal speed after capture, and decompression before sending. The risk is in analysing real, noisy signals.
- **Signals beyond the limit:** if the SRAM found becomes smaller between two boots, the signals in halves beyond the limit are no longer reachable. There is no check yet.
- **Carrier measurement:** the frequency is not measured; without a logic analyzer timing is validated only by symmetry and by tests on a console.
- **Sample metadata:** the signal does not store the carrier period or the speed it was captured at.
- **Event log:** it is as reliable as the SRAM. It has no checksum, and a write that fails is silent.

## 14. Hardware used for testing

A list of all the hardware this code was tried on. It must be updated every time a new device is tried.

### Flashcarts

| # | Device | How identified | Configurations tried | Result |
|---|---|---|---|---|
| 1 | Flashcart sold as "Game Flash GB PRO (Bitfunx), OS V4" [N1]. The card says "EverDrive GB MAX". | `GBOS.GB` has `KRKZ` in its header: it is the Krikzz EverDrive GB system (section 12). | SRAM header 128 KB: the probe answered `ALIAS`. SRAM header 32 KB: 4 banks. | Recording, naming and replay work. With the cards feature: no error at boot. Persistence after a power-off: to be verified. |

There is only one flashcart so far. No other card has been tried.

### Other hardware and tools

| Item | Detail |
|---|---|
| Console | Game Boy Color (model not recorded) |
| Remote | not identified (power-on signal) |
| microSD | holds `/EDGB/SAVE/gbc-remote.srm` (32 KB) and the `System Volume Information` folder (FAT). The extracted files are in `../file-scheda/`. |
| Emulator | PyBoy 2.9.0 [R9], Python 3.13.5, no window |
| Assembler | RGBDS 1.0.4 [R6][R8] |
| Measuring tools | none (no logic analyzer, no oscilloscope) |

## 15. Test coverage

`make coverage` runs the suites with a hook on every label of the code and generates:

- `docs/COVERAGE.md`: total percentage, per suite, per module, and the list of labels not reached;
- `build/coverage/summary.json`: the numbers the badges are made from (label coverage, tests passed and total for the unit, flow and debug suites).

**Badges.** No badge image is stored in the repository. The workflow `.github/workflows/badges.yml` runs on every push to `Main` or `develop` (and by hand). It installs RGBDS, runs `make test` and `make coverage`, turns the summary into step outputs with `tests/badge_outputs.py`, and calls the GitHub Action *Bring Your Own Badge* [R11] once per badge: `coverage`, `unit-tests`, `flow-tests`, `debug-tests`, `platform`, `hardware-tests`. The action writes the badge data in a JSON file on the `shields` branch, and a hosted endpoint turns it into the badge shown by the README (`https://byob.yarr.is/Bbxblack00/GBC-remote/<badge name>`). Colors: green from 85% coverage, yellow-green from 70%, orange from 50%, red below; a suite is green only if every test passed. The `platform` and `hardware tests` badges are fixed values set in the workflow (`PLATFORM_STATUS`, `HARDWARE_STATUS`): `HARDWARE_STATUS` MUST be changed by hand when the hardware verification changes.

The action is third party and not certified by GitHub [R11]. A push to a branch other than `Main` or `develop` does not update the badges. The workflow itself was not run yet: it is validated only as YAML, and the pieces it calls (`make test`, `make coverage`, `badge_outputs.py`) were run locally.

**What it measures.** A label (routine or branch target) counts as covered if the program reaches it at least once during the tests. It is an approximate coverage of code blocks, **not** line coverage and not coverage of data values. The labels come from the debug build, which holds every label of the normal build plus the debug screen. Hits come from the unit tests, the flow tests on the normal ROM, and the flow tests on the debug ROM.

**What it excludes.** The tables in `src/data/`, the ROM header, and all test code.

**Limits.**
- It measures what the tests run on the emulator, not what runs on a console.
- Points reached only by the infrared sensor simulators are counted as covered when the simulator hook fires.
- A high percentage does not prove the tests check enough: it only means the code is executed.
- At the time of writing the only label not reached is `Storage_Mount.reformatFailed`: it needs an SRAM write to fail during the reformat, and the emulator does not do that. The up-to-date list is in `docs/COVERAGE.md`.
- How the hook works: each label is hooked with PyBoy's `hook_register` [R9] and the hook is removed after the first hit. The removal happens after every emulator step, not inside the hook callback, because there PyBoy raises an error and slows execution a lot.

## 16. References

Official sources, consulted on 11/15/2026 (page opened and content checked):

- **[R1]** Pan Docs, *CGB Registers*: `KEY1` (`$FF4D`, speed switch, the CPU halts 2050 M-cycles after `stop`) and `RP` (`$FF56`, infrared port). <https://gbdev.io/pandocs/CGB_Registers.html>
- **[R2]** Pan Docs, *MBC5*: RAM enable `$0000`–`$1FFF` (`$0A`), RAM bank number `$4000`–`$5FFF` (`$00`–`$0F`). <https://gbdev.io/pandocs/MBC5.html>
- **[R3]** Pan Docs, *The Cartridge Header*: CGB flag `$0143`, type `$0147`, ROM size `$0148`, RAM size `$0149`. <https://gbdev.io/pandocs/The_Cartridge_Header.html>
- **[R4]** Pan Docs, *Joypad Input*: register `P1/JOYP` (`$FF00`). <https://gbdev.io/pandocs/Joypad_Input.html>
- **[R5]** Pan Docs, *Audio Registers*: `NR10`–`NR14`, `NR50`–`NR52`. <https://gbdev.io/pandocs/Audio_Registers.html>
- **[R6]** RGBDS, *rgbasm(5)*: the assembly language (`CHARMAP`, `MACRO`, `FOR`, sections). <https://rgbds.gbdev.io/docs/v1.0.4/rgbasm.5>
- **[R7]** RGBDS, *gbz80(7)*: instruction reference with cycle counts. <https://rgbds.gbdev.io/docs/v1.0.4/gbz80.7>
- **[R8]** RGBDS, *rgbfix(1)*: options `-C`, `-m`, `-r`, `-t`. <https://rgbds.gbdev.io/docs/v1.0.4/rgbfix.1>
- **[R9]** PyBoy, documentation and sources (version 2.9.0). <https://docs.pyboy.dk/> and <https://github.com/Baekalfen/PyBoy>
- **[R10]** RGBDS, releases: <https://github.com/gbdev/rgbds/releases>
- **[R11]** Bring Your Own Badge (RubbaBoy/BYOB), GitHub Marketplace page and `action.yml` of version 1.3.0: inputs `name`, `label`, `icon`, `status`, `color`, `github_token`, `path`, `branch`; data stored on the `shields` branch. <https://github.com/marketplace/actions/bring-your-own-badge> and <https://github.com/RubbaBoy/BYOB>

Unofficial sources (sellers and forums), seen as search results and **not checked in detail**. There is no manual for the card used; what follows is indicative:

- **[N1]** Handheld Legend, *Game Flash GB PRO (Bitfunx)*: <https://handheldlegend.com/products/game-flash-gb-pro-bitfunx>
- **[N2]** Retro Game Repair Shop, *Game Flash GB Pro Plus*: <https://retrogamerepairshop.com/products/game-flash-gb-pro-plus>
- **[N3]** PicClick, listing *Game Flash GB PRO*: <https://picclick.com/Jeu-Flash-GB-PRO-Bitfunx-286054184684.html>
- **[N4]** Retromodding, *Krikzz EverDrive GB X7*: <https://www.retromodding.com/collections/vendors/products/krikzz-everdrive-gb-x7>
- **[N5]** Stone Age Gamer, *EverDrive GB X7*: <https://stoneagegamer.com/everdrive-gb-x7-base.html>
- **[N6]** r/everdrive, *how to save state with GB X7* (copy on a mirror): <https://redlib.belloworld.it/r/everdrive/comments/1g9b2n9/how_to_save_state_with_gb_x7>

Things deduced from files: the menu of the `GBOS.GB` system (entries `Load And Start`, `Copy SRAM To File`, path `/EDGB/SAVE`) comes from analysing the strings of the file extracted from the card, not from a manual.
