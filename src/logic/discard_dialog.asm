INCLUDE "common.inc"

SECTION "DiscardDialog", ROM0

DiscardDialog_Run::
    call Screen_Begin
    PrintTextAt DIALOG_QUESTION_ROW, DIALOG_QUESTION_COLUMN, StringDiscardQuestion
    PrintTextAt DIALOG_DETAIL_ROW, DIALOG_DETAIL_COLUMN, StringDiscardDetail
    PrintTextAt DIALOG_WARNING_ROW, DISCARD_WARNING_COLUMN, StringDiscardWarning
    PrintTextAt LEGEND_FIRST_ROW, LEGEND_COLUMN, StringLegendDiscardFirst
    PrintTextAt LEGEND_SECOND_ROW, LEGEND_COLUMN, StringLegendDiscardSecond
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
