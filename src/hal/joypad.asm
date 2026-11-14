INCLUDE "common.inc"

SECTION "JoypadState", WRAM0
wJoypadHeld:: ds 1
wJoypadPressed:: ds 1

SECTION "Joypad", ROM0

Joypad_Read::
    ld a, JOYPAD_SELECT_DIRECTIONS
    ldh [rJOYP], a
    REPT JOYPAD_SETTLE_READ_COUNT
        ldh a, [rJOYP]
    ENDR
    or JOYPAD_UNUSED_HIGH_NIBBLE
    ld b, a

    ld a, JOYPAD_SELECT_BUTTONS
    ldh [rJOYP], a
    REPT JOYPAD_SETTLE_READ_COUNT
        ldh a, [rJOYP]
    ENDR
    or JOYPAD_UNUSED_HIGH_NIBBLE
    swap a
    xor b
    ld b, a

    ld a, JOYPAD_DESELECT_ALL
    ldh [rJOYP], a

    ld a, [wJoypadHeld]
    cpl
    and b
    ld [wJoypadPressed], a
    ld a, b
    ld [wJoypadHeld], a
    ret
