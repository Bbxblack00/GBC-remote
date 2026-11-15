INCLUDE "common.inc"

SECTION "SignalListScreenState", WRAM0
wSignalListCursor:: ds 1

SECTION "SignalListScreen", ROM0

SignalListScreen_Run::
    call SignalListScreen_LoadNames
    ld a, [wCardSignalCount]
    ld [wListViewCount], a
    ld a, [wSignalListCursor]
    ld [wListViewCursor], a
    call ListView_ClampCursor
    call SignalListScreen_Draw
.frameLoop
    call Lcd_WaitForVBlankStart
    call ListView_RenderCursor
    call Joypad_Read

    ld a, [wJoypadPressed]
    bit JOYPAD_BIT_UP, a
    call nz, SignalListScreen_MoveUp

    ld a, [wJoypadPressed]
    bit JOYPAD_BIT_DOWN, a
    call nz, SignalListScreen_MoveDown

    ld a, [wJoypadPressed]
    bit JOYPAD_BIT_B, a
    ld b, SIGNAL_LIST_ACTION_BACK
    jr nz, .leaveScreen
    bit JOYPAD_BIT_START, a
    ld b, SIGNAL_LIST_ACTION_NEW
    jr nz, .leaveScreen
    ld a, [wListViewCount]
    and a
    jr z, .frameLoop
    ld a, [wJoypadPressed]
    bit JOYPAD_BIT_A, a
    ld b, SIGNAL_LIST_ACTION_SEND
    jr nz, .leaveScreen
    bit JOYPAD_BIT_SELECT, a
    ld b, SIGNAL_LIST_ACTION_DELETE
    jr z, .frameLoop
.leaveScreen
    ld a, [wListViewCursor]
    ld [wSignalListCursor], a
    ld a, b
    ret

SignalListScreen_MoveUp:
    call ListView_MoveUp
    and a
    ret z
    jp SignalListScreen_Draw

SignalListScreen_MoveDown:
    call ListView_MoveDown
    and a
    ret z
    jp SignalListScreen_Draw

SignalListScreen_GetSelectedSlot::
    ld a, [wSignalListCursor]
    ld e, a
    ld d, 0
    ld hl, wCardSignalIndexes
    add hl, de
    ld a, [hl]
    ret

SignalListScreen_LoadNames:
    ld a, [wCardSignalCount]
    and a
    ret z
    ld c, 0
.loadName
    ld b, 0
    ld hl, wCardSignalIndexes
    add hl, bc
    ld a, [hl]
    call Storage_GetSignalEntryAddress
    ld de, SIGNAL_ENTRY_NAME_OFFSET
    add hl, de
    ld a, c
    call ListView_SetName
    inc c
    ld a, [wCardSignalCount]
    cp c
    jr nz, .loadName
    ret

SignalListScreen_Draw:
    call Screen_Begin
    ld a, [wSelectedCard]
    call Storage_GetCardEntryAddress
    inc hl
    ld d, h
    ld e, l
    ld hl, BACKGROUND_MAP_BASE + TITLE_ROW * BACKGROUND_MAP_ROW_STRIDE + TITLE_COLUMN
    ld b, NAME_LENGTH
    call Text_PrintGlyphs
    PrintTextAt LEGEND_FIRST_ROW, LEGEND_COLUMN, StringLegendListFirst
    PrintTextAt LEGEND_SECOND_ROW, LEGEND_COLUMN, StringLegendListSecond
    ld a, [wListViewCount]
    and a
    jr nz, .drawEntries
    PrintTextAt EMPTY_CARD_TITLE_ROW, EMPTY_CARD_TITLE_COLUMN, StringEmptyCard
    PrintTextAt EMPTY_CARD_HINT_ROW, EMPTY_CARD_HINT_COLUMN, StringEmptyCardHint
    jr .finishDrawing
.drawEntries
    call ListView_DrawNames
.finishDrawing
    call Screen_End
    ld a, THEME_NORMAL
    jp Theme_Apply
