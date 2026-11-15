INCLUDE "common.inc"

SECTION "CardListScreenState", WRAM0
wCardListCursor:: ds 1

SECTION "CardListScreen", ROM0

CardListScreen_Run::
    call CardListScreen_LoadNames
    ld a, [wUsedCardCount]
    ld [wListViewCount], a
    ld a, [wCardListCursor]
    ld [wListViewCursor], a
    call ListView_ClampCursor
    call CardListScreen_Draw
.frameLoop
    call Lcd_WaitForVBlankStart
    call ListView_RenderCursor
    call Joypad_Read

    ld a, [wJoypadPressed]
    bit JOYPAD_BIT_UP, a
    call nz, CardListScreen_MoveUp

    ld a, [wJoypadPressed]
    bit JOYPAD_BIT_DOWN, a
    call nz, CardListScreen_MoveDown

    ld a, [wJoypadPressed]
    bit JOYPAD_BIT_START, a
    ld b, CARD_LIST_ACTION_NEW
    jr nz, .leaveScreen
    bit JOYPAD_BIT_SELECT, a
    ld b, CARD_LIST_ACTION_DELETE
    jr nz, .leaveScreen
    bit JOYPAD_BIT_A, a
    ld b, CARD_LIST_ACTION_OPEN
    jr z, .frameLoop
.leaveScreen
    ld a, [wListViewCursor]
    ld [wCardListCursor], a
    ld a, b
    ret

CardListScreen_MoveUp:
    call ListView_MoveUp
    and a
    ret z
    jp CardListScreen_Draw

CardListScreen_MoveDown:
    call ListView_MoveDown
    and a
    ret z
    jp CardListScreen_Draw

CardListScreen_GetSelectedCard::
    ld a, [wCardListCursor]
    ld e, a
    ld d, 0
    ld hl, wUsedCardIndexes
    add hl, de
    ld a, [hl]
    ret

CardListScreen_LoadNames:
    ld a, [wUsedCardCount]
    and a
    ret z
    ld c, 0
.loadName
    ld b, 0
    ld hl, wUsedCardIndexes
    add hl, bc
    ld a, [hl]
    call Storage_GetCardEntryAddress
    inc hl
    ld a, c
    call ListView_SetName
    inc c
    ld a, [wUsedCardCount]
    cp c
    jr nz, .loadName
    ret

CardListScreen_Draw:
    call Screen_Begin
    PrintTextAt TITLE_ROW, TITLE_COLUMN, StringTitleCards
    PrintTextAt LEGEND_FIRST_ROW, LEGEND_COLUMN, StringLegendCardsFirst
    PrintTextAt LEGEND_SECOND_ROW, LEGEND_COLUMN, StringLegendListSecond
    ld hl, BACKGROUND_MAP_BASE + TITLE_ROW * BACKGROUND_MAP_ROW_STRIDE + USAGE_COLUMN
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
    call ListView_DrawNames
    call Screen_End
    ld a, THEME_NORMAL
    jp Theme_Apply
