INCLUDE "common.inc"

SECTION "ErrorScreenState", WRAM0
wDisplayedErrorCode: ds 1

SECTION "ErrorScreen", ROM0

ErrorScreen_Show::
    ld [wDisplayedErrorCode], a
    call Screen_Begin
    PrintTextAt ERROR_TITLE_ROW, ERROR_TITLE_COLUMN, StringErrorPrefix
    PrintTextAt ERROR_HINT_ROW, ERROR_HINT_COLUMN, StringErrorHint
    PrintTextAt LEGEND_FIRST_ROW, LEGEND_COLUMN, StringLegendError
    ld hl, BACKGROUND_MAP_BASE + ERROR_TITLE_ROW * BACKGROUND_MAP_ROW_STRIDE + ERROR_TITLE_COLUMN + ERROR_CODE_COLUMN_OFFSET
    ld a, [wDisplayedErrorCode]
    call Text_PrintDecimalByte
    call ErrorScreen_PrintProbeResult
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

ErrorScreen_PrintProbeResult:
    ld a, [wDisplayedErrorCode]
    cp ERROR_DIRECTORY_CORRUPT
    jr z, .printResult
    cp ERROR_STORAGE_VERIFY_FAILED
    ret nz
.printResult
    ld hl, BACKGROUND_MAP_BASE + ERROR_PROBE_BANKS_ROW * BACKGROUND_MAP_ROW_STRIDE + ERROR_PROBE_COLUMN
    call SramProbe_PrintBankCount
    ld hl, BACKGROUND_MAP_BASE + ERROR_PROBE_KEPT_ROW * BACKGROUND_MAP_ROW_STRIDE + ERROR_PROBE_COLUMN
    jp SramProbe_PrintKept
