INCLUDE "common.inc"
INCLUDE "test_framework.inc"

MACRO SetKeyboardCursor
    ld a, \1
    ld [wKeyboardCursor], a
ENDM

SECTION "KeyboardTests", ROM0

Test_KeyboardRightWrapsToStart::
    SetKeyboardCursor 0
    call Keyboard_MoveRight
    ld a, [wKeyboardCursor]
    ExpectEqual 1
    SetKeyboardCursor KEYBOARD_KEY_COUNT - 1
    call Keyboard_MoveRight
    ld a, [wKeyboardCursor]
    ExpectZero
    TestPassed

Test_KeyboardLeftWrapsToEnd::
    SetKeyboardCursor 5
    call Keyboard_MoveLeft
    ld a, [wKeyboardCursor]
    ExpectEqual 4
    SetKeyboardCursor 0
    call Keyboard_MoveLeft
    ld a, [wKeyboardCursor]
    ExpectEqual KEYBOARD_KEY_COUNT - 1
    TestPassed

Test_KeyboardDownKeepsColumn::
    SetKeyboardCursor 0
    call Keyboard_MoveDown
    ld a, [wKeyboardCursor]
    ExpectEqual KEYBOARD_COLUMNS
    SetKeyboardCursor KEYBOARD_KEY_COUNT - KEYBOARD_COLUMNS + 5
    call Keyboard_MoveDown
    ld a, [wKeyboardCursor]
    ExpectEqual 5
    TestPassed

Test_KeyboardUpKeepsColumn::
    SetKeyboardCursor KEYBOARD_COLUMNS
    call Keyboard_MoveUp
    ld a, [wKeyboardCursor]
    ExpectZero
    SetKeyboardCursor 3
    call Keyboard_MoveUp
    ld a, [wKeyboardCursor]
    ExpectEqual KEYBOARD_KEY_COUNT - KEYBOARD_COLUMNS + 3
    TestPassed

Test_KeyboardGlyphLookup::
    SetKeyboardCursor 0
    call Keyboard_GetCursorGlyph
    ExpectEqual GLYPH_LETTER_A
    SetKeyboardCursor 25
    call Keyboard_GetCursorGlyph
    ExpectEqual GLYPH_LETTER_A + 25
    SetKeyboardCursor 26
    call Keyboard_GetCursorGlyph
    ExpectEqual GLYPH_DIGIT_0
    SetKeyboardCursor 35
    call Keyboard_GetCursorGlyph
    ExpectEqual GLYPH_DIGIT_0 + 9
    SetKeyboardCursor KEYBOARD_KEY_COUNT - 1
    call Keyboard_GetCursorGlyph
    ExpectEqual GLYPH_SPACE
    TestPassed
