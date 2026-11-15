INCLUDE "common.inc"

IF DEF(DEBUG_BUILD)

SECTION "DebugScreenState", WRAM0
wDebugPage: ds 1

SECTION "DebugScreen", ROM0

DebugScreen_Run::
    xor a
    ld [wDebugPage], a
.drawPage
    call DebugScreen_Draw
.waitForInput
    call Lcd_WaitForVBlankStart
    call Joypad_Read
    ld a, [wJoypadPressed]
    bit JOYPAD_BIT_B, a
    ret nz
    bit JOYPAD_BIT_A, a
    jr z, .waitForInput
    ld a, [wDebugPage]
    xor 1
    ld [wDebugPage], a
    jr .drawPage

DebugScreen_Draw:
    call Screen_Begin
    PrintTextAt TITLE_ROW, TITLE_COLUMN, StringDebugTitle
    PrintTextAt LEGEND_FIRST_ROW, LEGEND_COLUMN, StringDebugLegend
    ld a, [wDebugPage]
    and a
    jr nz, .drawCardsPage
    call DebugScreen_DrawSystemPage
    jr .pageDrawn
.drawCardsPage
    call DebugScreen_DrawCardsPage
.pageDrawn
    call Screen_End
    ld a, THEME_NORMAL
    jp Theme_Apply

DebugScreen_GetRowAddress:
    ld l, a
    ld h, 0
    REPT LIST_ROW_STRIDE_SHIFT
        add hl, hl
    ENDR
    ld de, BACKGROUND_MAP_BASE + DEBUG_FIRST_ROW * BACKGROUND_MAP_ROW_STRIDE + DEBUG_COLUMN
    add hl, de
    ret

DebugScreen_DrawSystemPage:
    ld a, 0
    call DebugScreen_GetRowAddress
    ld de, StringDebugBoot
    call Text_PrintString
    ld a, [wBootCounter]
    ld e, a
    ld a, [wBootCounter + 1]
    ld d, a
    call Text_PrintDecimalWord

    ld a, 1
    call DebugScreen_GetRowAddress
    ld de, StringDebugSpeed
    call Text_PrintString
    ldh a, [rKEY1]
    and KEY1_DOUBLE_SPEED_ACTIVE
    ld de, StringDebugNormal
    jr z, .printSpeed
    ld de, StringDebugDouble
.printSpeed
    call Text_PrintString

    ld a, 2
    call DebugScreen_GetRowAddress
    call SramProbe_PrintBankCount
    ld a, 3
    call DebugScreen_GetRowAddress
    call SramProbe_PrintKept

    ld a, 4
    call DebugScreen_GetRowAddress
    ld de, StringUsageLabel
    call Text_PrintString
    push hl
    call Storage_CountUsedSignals
    pop hl
    call Text_PrintDecimalByte
    ld de, StringUsageSeparator
    call Text_PrintString
    ld a, [wSignalSlotLimit]
    call Text_PrintDecimalByte

    ld a, 5
    call DebugScreen_GetRowAddress
    ld de, StringDebugCards
    call Text_PrintString
    ld a, [wUsedCardCount]
    call Text_PrintDecimalByte
    ld de, StringUsageSeparator
    call Text_PrintString
    ld a, CARD_COUNT_MAX
    call Text_PrintDecimalByte

    ld a, 6
    call DebugScreen_GetRowAddress
    ld de, StringDebugDirectory
    call Text_PrintString
    push hl
    call Storage_ComputeDirectoryBytesInUse
    pop hl
    call Text_PrintDecimalWord
    ld de, StringUsageSeparator
    call Text_PrintString
    ld de, DIRECTORY_SIZE_BYTES
    call Text_PrintDecimalWord

    ld a, 7
    call DebugScreen_GetRowAddress
    ld de, StringDebugPrimary
    call Text_PrintString
    ld a, [wDirectoryPrimaryClass]
    call DebugScreen_PrintDirectoryClass

    ld a, 8
    call DebugScreen_GetRowAddress
    ld de, StringDebugBackup
    call Text_PrintString
    ld a, [wDirectoryBackupClass]
    call DebugScreen_PrintDirectoryClass

    ld a, 10
    call DebugScreen_GetRowAddress
    ld de, StringDebugLastError
    call Text_PrintString
    ld a, [wLastErrorCode]
    and a
    jr nz, .printLastError
    ld de, StringDebugNone
    jp Text_PrintString
.printLastError
    push af
    ld de, StringDebugErrorPrefix
    call Text_PrintString
    pop af
    jp Text_PrintDecimalByte

DebugScreen_PrintDirectoryClass:
    add a
    ld e, a
    ld d, 0
    push hl
    ld hl, DirectoryClassNames
    add hl, de
    ld a, [hli]
    ld d, [hl]
    ld e, a
    pop hl
    jp Text_PrintString

DebugScreen_DrawCardsPage:
    ld a, 0
    call DebugScreen_GetRowAddress
    ld de, StringDebugCardsPage
    call Text_PrintString
    ld c, 0
.drawCell
    push bc
    ld a, c
    srl a
    srl a
    inc a
    call DebugScreen_GetRowAddress
    pop bc
    push bc
    ld a, c
    and DEBUG_GRID_COLUMNS - 1
    ld e, a
    add a
    add a
    add e
    ld e, a
    ld d, 0
    add hl, de
    pop bc
    push bc
    ld a, c
    call Text_PrintDecimalByte
    ld a, GLYPH_COLON
    ld [hli], a
    pop bc
    push bc
    push hl
    ld a, c
    call Storage_GetCardEntryAddress
    ld a, [hl]
    pop hl
    cp ENTRY_STATUS_USED
    jr z, .cardUsed
    ld a, GLYPH_DASH
    ld [hl], a
    jr .cellDrawn
.cardUsed
    pop bc
    push bc
    push hl
    ld a, c
    call Storage_RebuildSignalIndex
    pop hl
    ld a, [wCardSignalCount]
    add GLYPH_DIGIT_0
    ld [hl], a
.cellDrawn
    pop bc
    inc c
    ld a, c
    cp CARD_COUNT_MAX
    jr nz, .drawCell
    ret

ENDC
