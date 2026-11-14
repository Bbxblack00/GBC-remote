INCLUDE "common.inc"

SECTION "ListScreenState", WRAM0
wListCursor:: ds 1

SECTION "ListScreen", ROM0

ListScreen_Run::
    call ListScreen_ClampCursor
    call ListScreen_Draw
.frameLoop
    call Lcd_WaitForVBlankStart
    call ListScreen_RenderCursor
    call Joypad_Read

    ld a, [wJoypadPressed]
    bit JOYPAD_BIT_UP, a
    call nz, ListScreen_MoveUp

    ld a, [wJoypadPressed]
    bit JOYPAD_BIT_DOWN, a
    call nz, ListScreen_MoveDown

    ld a, [wJoypadPressed]
    bit JOYPAD_BIT_A, a
    jr z, .checkDeleteRequest
    ld a, LIST_ACTION_SEND
    ret
.checkDeleteRequest
    ld a, [wJoypadPressed]
    bit JOYPAD_BIT_SELECT, a
    jr z, .checkNewSignalRequest
    ld a, LIST_ACTION_DELETE
    ret
.checkNewSignalRequest
    ld a, [wJoypadPressed]
    bit JOYPAD_BIT_START, a
    jr z, .frameLoop
    ld a, LIST_ACTION_NEW
    ret

ListScreen_ClampCursor::
    ld a, [wUsedSlotCount]
    ld b, a
    ld a, [wListCursor]
    cp b
    ret c
    ld a, b
    dec a
    ld [wListCursor], a
    ret

ListScreen_MoveUp::
    ld a, [wListCursor]
    and a
    ret z
    dec a
    ld [wListCursor], a
    ret

ListScreen_MoveDown::
    ld a, [wListCursor]
    inc a
    ld b, a
    ld a, [wUsedSlotCount]
    cp b
    ret c
    ret z
    ld a, b
    ld [wListCursor], a
    ret

ListScreen_GetSelectedSlot::
    ld a, [wListCursor]
    jp ListScreen_GetSlotAtIndex

ListScreen_GetSlotAtIndex::
    ld e, a
    ld d, 0
    ld hl, wUsedSlotIndexes
    add hl, de
    ld a, [hl]
    ret

ListScreen_GetRowAddress:
    ld l, a
    ld h, 0
    REPT LIST_ROW_STRIDE_SHIFT
        add hl, hl
    ENDR
    ld de, BACKGROUND_MAP_BASE + LIST_FIRST_ROW * BACKGROUND_MAP_ROW_STRIDE
    add hl, de
    ret

ListScreen_Draw:
    call Screen_Begin
    PrintTextAt TITLE_ROW, TITLE_COLUMN, StringTitleList
    PrintTextAt LEGEND_FIRST_ROW, LEGEND_COLUMN, StringLegendListFirst
    PrintTextAt LEGEND_SECOND_ROW, LEGEND_COLUMN, StringLegendListSecond
    ld c, 0
.drawName
    ld a, c
    call ListScreen_GetRowAddress
    ld de, LIST_NAME_COLUMN
    add hl, de
    push hl
    ld a, c
    call ListScreen_GetSlotAtIndex
    call Storage_GetEntryAddress
    inc hl
    ld d, h
    ld e, l
    pop hl
    ld b, NAME_LENGTH
    call Text_PrintGlyphs
    inc c
    ld a, [wUsedSlotCount]
    cp c
    jr nz, .drawName
    call Screen_End
    ld a, THEME_NORMAL
    jp Theme_Apply

ListScreen_RenderCursor:
    ld c, 0
.renderCell
    ld a, c
    call ListScreen_GetRowAddress
    ld de, LIST_CURSOR_COLUMN
    add hl, de
    ld a, [wListCursor]
    cp c
    ld a, GLYPH_SPACE
    jr nz, .writeCell
    ld a, GLYPH_CURSOR
.writeCell
    ld [hl], a
    inc c
    ld a, [wUsedSlotCount]
    cp c
    jr nz, .renderCell
    ret
