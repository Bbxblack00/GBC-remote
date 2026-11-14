INCLUDE "common.inc"

SECTION "ErrorScreen", ROM0

ErrorScreen_Show::
    push af
    call Screen_Begin
    PrintTextAt ERROR_TITLE_ROW, ERROR_TITLE_COLUMN, StringErrorPrefix
    PrintTextAt ERROR_HINT_ROW, ERROR_HINT_COLUMN, StringErrorHint
    PrintTextAt LEGEND_FIRST_ROW, LEGEND_COLUMN, StringLegendError
    ld hl, BACKGROUND_MAP_BASE + ERROR_TITLE_ROW * BACKGROUND_MAP_ROW_STRIDE + ERROR_TITLE_COLUMN + ERROR_CODE_COLUMN_OFFSET
    pop af
    call Text_PrintDecimalByte
    call Screen_End
    ld a, THEME_ALERT
    call Theme_Apply
.waitForConfirmation
    call Lcd_WaitForVBlankStart
    call Joypad_Read
    ld a, [wJoypadPressed]
    bit JOYPAD_BIT_A, a
    jr z, .waitForConfirmation
    ret
