INCLUDE "common.inc"

SECTION "DeleteDialog", ROM0

DeleteDialog_Run::
    call Screen_Begin
    PrintTextAt DIALOG_QUESTION_ROW, DIALOG_QUESTION_COLUMN, StringDeleteQuestion
    PrintTextAt DIALOG_WARNING_ROW, DIALOG_WARNING_COLUMN, StringDeleteWarning
    PrintTextAt LEGEND_FIRST_ROW, LEGEND_COLUMN, StringLegendDelete
    ld a, [wTargetSlot]
    call Storage_GetEntryAddress
    inc hl
    ld d, h
    ld e, l
    ld hl, BACKGROUND_MAP_BASE + DIALOG_NAME_ROW * BACKGROUND_MAP_ROW_STRIDE + DIALOG_NAME_COLUMN
    ld b, NAME_LENGTH
    call Text_PrintGlyphs
    call Screen_End
    ld a, THEME_ALERT
    call Theme_Apply
.waitForAnswer
    call Lcd_WaitForVBlankStart
    call Joypad_Read
    ld a, [wJoypadPressed]
    bit JOYPAD_BIT_A, a
    jr nz, .answeredYes
    bit JOYPAD_BIT_B, a
    jr z, .waitForAnswer
    Throw ERROR_CANCELLED
.answeredYes
    Succeed
