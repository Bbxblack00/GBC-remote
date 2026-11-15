INCLUDE "common.inc"

SECTION "SramDiagnosticState", WRAM0
wDiagnosticBankResults:: ds DIAGNOSTIC_BANK_COUNT

SECTION "SramDiagnostic", ROM0

SramDiagnostic_Run::
    call SramDiagnostic_DrawMenu
.menuLoop
    call Lcd_WaitForVBlankStart
    call Joypad_Read
    ld a, [wJoypadPressed]
    bit JOYPAD_BIT_A, a
    jr nz, .writePatterns
    bit JOYPAD_BIT_START, a
    jr nz, .verifyPatterns
    bit JOYPAD_BIT_B, a
    jr z, .menuLoop
    ret
.writePatterns
    call SramDiagnostic_WriteAllBanks
.verifyPatterns
    call SramDiagnostic_VerifyAllBanks
    call SramDiagnostic_DrawResults
    call SramDiagnostic_WaitForConfirmation
    jr SramDiagnostic_Run

SramDiagnostic_WaitForConfirmation:
.waitForPress
    call Lcd_WaitForVBlankStart
    call Joypad_Read
    ld a, [wJoypadPressed]
    bit JOYPAD_BIT_A, a
    ret nz
    bit JOYPAD_BIT_B, a
    jr z, .waitForPress
    ret

SramDiagnostic_WriteAllBanks:
    call Sram_Enable
    ld c, 0
.writeBank
    ld a, c
    call Sram_SelectBank
    ld a, c
    xor DIAGNOSTIC_PATTERN_KEY
    ld d, a
    ld hl, SRAM_BASE_ADDRESS
.writeByte
    call SramDiagnostic_IsProbeByte
    jr z, .skipByte
    ld a, l
    xor d
    ld [hl], a
.skipByte
    inc hl
    ld a, h
    cp SRAM_END_HIGH_BYTE
    jr nz, .writeByte
    inc c
    ld a, c
    cp DIAGNOSTIC_BANK_COUNT
    jr nz, .writeBank
    jp Sram_Disable

SramDiagnostic_VerifyAllBanks:
    call Sram_Enable
    ld c, 0
.verifyBank
    ld a, c
    call Sram_SelectBank
    ld a, c
    xor DIAGNOSTIC_PATTERN_KEY
    ld d, a
    ld e, DIAGNOSTIC_BANK_OK
    ld hl, SRAM_BASE_ADDRESS
.verifyByte
    call SramDiagnostic_IsProbeByte
    jr z, .byteMatches
    ld a, l
    xor d
    cp [hl]
    jr z, .byteMatches
    ld e, DIAGNOSTIC_BANK_BAD
.byteMatches
    inc hl
    ld a, h
    cp SRAM_END_HIGH_BYTE
    jr nz, .verifyByte
    ld hl, wDiagnosticBankResults
    ld b, 0
    add hl, bc
    ld [hl], e
    inc c
    ld a, c
    cp DIAGNOSTIC_BANK_COUNT
    jr nz, .verifyBank
    jp Sram_Disable

SramDiagnostic_DrawMenu:
    call Screen_Begin
    PrintTextAt TITLE_ROW, TITLE_COLUMN, StringDiagnosticTitle
    PrintTextAt DIAGNOSTIC_MENU_WRITE_ROW, DIAGNOSTIC_MENU_COLUMN, StringDiagnosticWrite
    PrintTextAt DIAGNOSTIC_MENU_CYCLE_ROW, DIAGNOSTIC_MENU_COLUMN, StringDiagnosticCycle
    PrintTextAt DIAGNOSTIC_MENU_HOLD_ROW, DIAGNOSTIC_MENU_COLUMN, StringDiagnosticHold
    PrintTextAt DIAGNOSTIC_MENU_VERIFY_ROW, DIAGNOSTIC_MENU_COLUMN, StringDiagnosticVerify
    PrintTextAt DIAGNOSTIC_MENU_EXIT_ROW, DIAGNOSTIC_MENU_COLUMN, StringDiagnosticExit
    PrintTextAt DIAGNOSTIC_MENU_WARNING_ROW, DIAGNOSTIC_MENU_COLUMN, StringDiagnosticWarning
    ld hl, BACKGROUND_MAP_BASE + DIAGNOSTIC_MENU_BANKS_ROW * BACKGROUND_MAP_ROW_STRIDE + ERROR_PROBE_COLUMN
    call SramProbe_PrintBankCount
    ld hl, BACKGROUND_MAP_BASE + DIAGNOSTIC_MENU_KEPT_ROW * BACKGROUND_MAP_ROW_STRIDE + ERROR_PROBE_COLUMN
    call SramProbe_PrintKept
    call Screen_End
    ld a, THEME_NORMAL
    jp Theme_Apply

SramDiagnostic_DrawResults:
    call Screen_Begin
    PrintTextAt TITLE_ROW, TITLE_COLUMN, StringDiagnosticTitle
    PrintTextAt LEGEND_FIRST_ROW, LEGEND_COLUMN, StringLegendError
    ld c, 0
.drawBankRow
    ld a, c
    and DIAGNOSTIC_ROW_MASK
    call SramDiagnostic_GetRowAddress
    ld a, c
    cp DIAGNOSTIC_ROWS_PER_COLUMN
    jr c, .columnSelected
    ld de, DIAGNOSTIC_COLUMN_WIDTH
    add hl, de
.columnSelected
    ld de, StringDiagnosticBank
    call Text_PrintString
    push bc
    ld a, c
    call Text_PrintDecimalByte
    pop bc
    inc hl
    push hl
    ld hl, wDiagnosticBankResults
    ld b, 0
    add hl, bc
    ld a, [hl]
    pop hl
    ld de, StringDiagnosticOk
    and a
    jr z, .printVerdict
    ld de, StringDiagnosticBad
.printVerdict
    call Text_PrintString
    inc c
    ld a, c
    cp DIAGNOSTIC_BANK_COUNT
    jr nz, .drawBankRow
    call SramDiagnostic_AreAllBanksOk
    ld de, StringDiagnosticAllOk
    jr z, .printSummary
    ld de, StringDiagnosticSomeBad
.printSummary
    ld hl, BACKGROUND_MAP_BASE + DIAGNOSTIC_SUMMARY_ROW * BACKGROUND_MAP_ROW_STRIDE + DIAGNOSTIC_SUMMARY_COLUMN
    call Text_PrintString
    call Screen_End
    ld a, THEME_NORMAL
    jp Theme_Apply

SramDiagnostic_GetRowAddress:
    ld l, a
    ld h, 0
    REPT LIST_ROW_STRIDE_SHIFT
        add hl, hl
    ENDR
    ld de, BACKGROUND_MAP_BASE + DIAGNOSTIC_FIRST_ROW * BACKGROUND_MAP_ROW_STRIDE
    add hl, de
    ret

SramDiagnostic_IsProbeByte:
    ld a, h
    cp HIGH(SRAM_PROBE_ADDRESS)
    ret nz
    ld a, l
    cp LOW(SRAM_PROBE_ADDRESS)
    ret
SramDiagnostic_AreAllBanksOk:
    ld hl, wDiagnosticBankResults
    ld b, DIAGNOSTIC_BANK_COUNT
    xor a
.combineResult
    or [hl]
    inc hl
    dec b
    jr nz, .combineResult
    and a
    ret
