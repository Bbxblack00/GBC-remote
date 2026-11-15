INCLUDE "common.inc"

SECTION "NameEntryState", WRAM0
wInlineErrorCode:: ds 1
wNameEntryKind:: ds 1

SECTION "NameEntryScreen", ROM0

NameEntryScreen_Run::
    ld [wNameEntryKind], a
    call NameBuffer_Clear
    xor a
    ld [wKeyboardCursor], a
    ld [wInlineErrorCode], a
    call NameEntryScreen_Draw
.frameLoop
    call Lcd_WaitForVBlankStart
    call Keyboard_RenderCursor
    call NameEntryScreen_RenderName
    call NameEntryScreen_RenderInlineError
    call Joypad_Read

    ld a, [wJoypadPressed]
    bit JOYPAD_BIT_RIGHT, a
    call nz, Keyboard_MoveRight

    ld a, [wJoypadPressed]
    bit JOYPAD_BIT_LEFT, a
    call nz, Keyboard_MoveLeft

    ld a, [wJoypadPressed]
    bit JOYPAD_BIT_DOWN, a
    call nz, Keyboard_MoveDown

    ld a, [wJoypadPressed]
    bit JOYPAD_BIT_UP, a
    call nz, Keyboard_MoveUp

    ld a, [wJoypadPressed]
    bit JOYPAD_BIT_A, a
    call nz, NameEntryScreen_PickKey

    ld a, [wJoypadPressed]
    bit JOYPAD_BIT_B, a
    jr z, .checkSaveRequest
    ld a, [wNameLength]
    and a
    jr nz, .removeLastGlyph
    Throw ERROR_CANCELLED
.removeLastGlyph
    call NameBuffer_RemoveLast
    xor a
    ld [wInlineErrorCode], a

.checkSaveRequest
    ld a, [wJoypadPressed]
    bit JOYPAD_BIT_START, a
    jr z, .frameLoop
    ld a, [wNameLength]
    and a
    jr nz, .validateName
    call NameEntryScreen_ConfirmDiscard
    and a
    jr nz, .discardRefused
    Throw ERROR_CANCELLED
.discardRefused
    call NameEntryScreen_Draw
    jr .frameLoop
.validateName
    call NameEntryScreen_ValidateName
    ld [wInlineErrorCode], a
    and a
    jr nz, .frameLoop
    Succeed

NameEntryScreen_PickKey:
    call Keyboard_GetCursorGlyph
    call NameBuffer_Append
    xor a
    ld [wInlineErrorCode], a
    ret

NameEntryScreen_ValidateName:
    ld a, [wNameEntryKind]
    cp NAME_KIND_SIGNAL
    jp z, Storage_ValidateSignalName
    jp Storage_ValidateCardName

NameEntryScreen_ConfirmDiscard:
    ld a, [wNameEntryKind]
    add a
    ld e, a
    ld d, 0
    ld hl, DiscardDialogDescriptors
    add hl, de
    ld a, [hli]
    ld h, [hl]
    ld l, a
    jp ConfirmDialog_Run

NameEntryScreen_Draw:
    call Screen_Begin
    ld a, [wNameEntryKind]
    add a
    ld e, a
    ld d, 0
    ld hl, NameEntryTitles
    add hl, de
    ld a, [hli]
    ld d, [hl]
    ld e, a
    ld hl, BACKGROUND_MAP_BASE + TITLE_ROW * BACKGROUND_MAP_ROW_STRIDE + TITLE_COLUMN
    call Text_PrintString
    PrintTextAt LEGEND_FIRST_ROW, LEGEND_COLUMN, StringLegendNameFirst
    PrintTextAt LEGEND_SECOND_ROW, LEGEND_COLUMN, StringLegendNameSecond
    call Keyboard_DrawKeys
    call Screen_End
    ld a, THEME_NORMAL
    jp Theme_Apply

NameEntryScreen_RenderName:
    ld hl, BACKGROUND_MAP_BASE + NAME_FIELD_ROW * BACKGROUND_MAP_ROW_STRIDE + NAME_FIELD_COLUMN
    ld de, wNameBuffer
    ld a, [wNameLength]
    ld c, a
    ld b, 0
.renderCell
    ld a, b
    cp c
    ld a, GLYPH_UNDERSCORE
    jr nc, .writeCell
    ld a, [de]
.writeCell
    ld [hli], a
    inc de
    inc b
    ld a, b
    cp NAME_LENGTH
    jr nz, .renderCell
    ret

NameEntryScreen_RenderInlineError:
    ld hl, BACKGROUND_MAP_BASE + NAME_STATUS_ROW * BACKGROUND_MAP_ROW_STRIDE + NAME_STATUS_COLUMN
    ld a, [wInlineErrorCode]
    and a
    jr nz, .printErrorCode
    ld bc, ERROR_STATUS_WIDTH
    ld a, GLYPH_SPACE
    jp Memory_FillBytes
.printErrorCode
    push af
    ld de, StringErrorPrefix
    call Text_PrintString
    pop af
    jp Text_PrintDecimalByte
