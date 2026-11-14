INCLUDE "common.inc"

SECTION "KeyboardState", WRAM0
wKeyboardCursor:: ds 1

SECTION "Keyboard", ROM0

Keyboard_MoveRight::
    ld a, [wKeyboardCursor]
    inc a
    cp KEYBOARD_KEY_COUNT
    jr c, .storeCursor
    xor a
.storeCursor
    ld [wKeyboardCursor], a
    ret

Keyboard_MoveLeft::
    ld a, [wKeyboardCursor]
    and a
    jr nz, .stepBack
    ld a, KEYBOARD_KEY_COUNT
.stepBack
    dec a
    ld [wKeyboardCursor], a
    ret

Keyboard_MoveDown::
    ld a, [wKeyboardCursor]
    add KEYBOARD_COLUMNS
    cp KEYBOARD_KEY_COUNT
    jr c, .storeCursor
    sub KEYBOARD_KEY_COUNT
.storeCursor
    ld [wKeyboardCursor], a
    ret

Keyboard_MoveUp::
    ld a, [wKeyboardCursor]
    sub KEYBOARD_COLUMNS
    jr nc, .storeCursor
    add KEYBOARD_KEY_COUNT
.storeCursor
    ld [wKeyboardCursor], a
    ret

Keyboard_GetCursorGlyph::
    ld a, [wKeyboardCursor]
    ld e, a
    ld d, 0
    ld hl, KeyboardGlyphs
    add hl, de
    ld a, [hl]
    ret

Keyboard_DrawKeys::
    ld hl, BACKGROUND_MAP_BASE + KEYBOARD_FIRST_ROW * BACKGROUND_MAP_ROW_STRIDE + 1
    ld de, KeyboardGlyphs
    ld c, KEYBOARD_ROWS
.drawRow
    ld b, KEYBOARD_COLUMNS
.drawKey
    ld a, [de]
    ld [hli], a
    inc hl
    inc de
    dec b
    jr nz, .drawKey
    call Keyboard_AdvanceToNextRow
    dec c
    jr nz, .drawRow
    ret

Keyboard_RenderCursor::
    ld hl, BACKGROUND_MAP_BASE + KEYBOARD_FIRST_ROW * BACKGROUND_MAP_ROW_STRIDE
    ld a, [wKeyboardCursor]
    ld c, a
    ld d, 0
    ld e, KEYBOARD_ROWS
.renderRow
    ld b, KEYBOARD_COLUMNS
.renderCell
    ld a, d
    cp c
    ld a, GLYPH_SPACE
    jr nz, .writeCell
    ld a, GLYPH_CURSOR
.writeCell
    ld [hli], a
    inc hl
    inc d
    dec b
    jr nz, .renderCell
    call Keyboard_AdvanceToNextRow
    dec e
    jr nz, .renderRow
    ret

Keyboard_AdvanceToNextRow:
    ld a, l
    add LOW(KEYBOARD_ROW_ADVANCE)
    ld l, a
    ld a, h
    adc HIGH(KEYBOARD_ROW_ADVANCE)
    ld h, a
    ret
