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
    call ErrorScreen_PrintMessage
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
    cp ERROR_DIRECTORY_VERIFY_FAILED
    jr z, .printResult
    cp ERROR_SAMPLE_VERIFY_FAILED
    ret nz
.printResult
    ld hl, BACKGROUND_MAP_BASE + ERROR_PROBE_BANKS_ROW * BACKGROUND_MAP_ROW_STRIDE + ERROR_PROBE_COLUMN
    call SramProbe_PrintBankCount
    ld hl, BACKGROUND_MAP_BASE + ERROR_PROBE_KEPT_ROW * BACKGROUND_MAP_ROW_STRIDE + ERROR_PROBE_COLUMN
    jp SramProbe_PrintKept

ErrorScreen_PrintMessage:
    ld a, [wDisplayedErrorCode]
    cp ERROR_STORAGE_FULL
    jr z, ErrorScreen_PrintStorageFullMessage
    cp ERROR_MESSAGE_TABLE_ENTRIES
    ret nc
    ld l, a
    ld h, 0
    add hl, hl
    ld d, h
    ld e, l
    add hl, hl
    add hl, de
    ld de, ErrorMessages
    add hl, de
    ld c, 0
.printLine
    ld a, [hli]
    ld e, a
    ld a, [hli]
    ld d, a
    or e
    jr z, .nextLine
    push hl
    push bc
    push de
    ld a, c
    call ErrorScreen_GetMessageRowAddress
    pop de
    call Text_PrintString
    pop bc
    pop hl
.nextLine
    inc c
    ld a, c
    cp ERROR_MESSAGE_LINES
    jr nz, .printLine
    ret

ErrorScreen_PrintStorageFullMessage:
    ld hl, BACKGROUND_MAP_BASE + ERROR_MESSAGE_FIRST_ROW * BACKGROUND_MAP_ROW_STRIDE + ERROR_MESSAGE_COLUMN
    ld de, StringErrorAll
    call Text_PrintString
    ld a, [wSignalSlotLimit]
    call Text_PrintDecimalByte
    ld de, StringErrorSignalSlots
    call Text_PrintString
    PrintTextAt ERROR_MESSAGE_FIRST_ROW + 1, ERROR_MESSAGE_COLUMN, StringErrorAreInUse
    ld hl, BACKGROUND_MAP_BASE + (ERROR_MESSAGE_FIRST_ROW + 2) * BACKGROUND_MAP_ROW_STRIDE + ERROR_MESSAGE_COLUMN
    jp SramProbe_PrintBankCount

ErrorScreen_GetMessageRowAddress:
    ld l, a
    ld h, 0
    REPT LIST_ROW_STRIDE_SHIFT
        add hl, hl
    ENDR
    ld de, BACKGROUND_MAP_BASE + ERROR_MESSAGE_FIRST_ROW * BACKGROUND_MAP_ROW_STRIDE + ERROR_MESSAGE_COLUMN
    add hl, de
    ret
