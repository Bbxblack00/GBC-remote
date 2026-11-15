INCLUDE "common.inc"

SECTION "ListViewState", WRAM0
wListViewCount:: ds 1
wListViewCursor:: ds 1
wListViewTop:: ds 1
wListViewNames:: ds CARD_COUNT_MAX * NAME_LENGTH

SECTION "ListView", ROM0

ListView_ClampCursor::
    ld a, [wListViewCount]
    and a
    jr nz, .listHasEntries
    xor a
    ld [wListViewCursor], a
    ld [wListViewTop], a
    ret
.listHasEntries
    ld b, a
    ld a, [wListViewCursor]
    cp b
    jr c, .cursorInRange
    ld a, b
    dec a
    ld [wListViewCursor], a
.cursorInRange
    xor a
    ld [wListViewTop], a
    jp ListView_EnsureCursorVisible

ListView_MoveUp::
    ld a, [wListViewCursor]
    and a
    jr z, .cannotMove
    dec a
    ld [wListViewCursor], a
    jp ListView_EnsureCursorVisible
.cannotMove
    ld a, LIST_REDRAW_NOT_NEEDED
    ret

ListView_MoveDown::
    ld a, [wListViewCursor]
    inc a
    ld b, a
    ld a, [wListViewCount]
    cp b
    jr z, .cannotMove
    jr c, .cannotMove
    ld a, b
    ld [wListViewCursor], a
    jp ListView_EnsureCursorVisible
.cannotMove
    ld a, LIST_REDRAW_NOT_NEEDED
    ret

ListView_EnsureCursorVisible::
    ld a, [wListViewTop]
    ld b, a
    ld a, [wListViewCursor]
    cp b
    jr nc, .checkBottomEdge
    ld [wListViewTop], a
    ld a, LIST_REDRAW_NEEDED
    ret
.checkBottomEdge
    ld a, b
    add LIST_VISIBLE_ROWS
    ld b, a
    ld a, [wListViewCursor]
    cp b
    jr c, .alreadyVisible
    sub LIST_VISIBLE_ROWS - 1
    ld [wListViewTop], a
    ld a, LIST_REDRAW_NEEDED
    ret
.alreadyVisible
    ld a, LIST_REDRAW_NOT_NEEDED
    ret

ListView_GetNameAddress::
    ld hl, wListViewNames
    and a
    ret z
    ld de, NAME_LENGTH
    ld b, a
.advanceToNextName
    add hl, de
    dec b
    jr nz, .advanceToNextName
    ret

ListView_SetName::
    push hl
    call ListView_GetNameAddress
    ld d, h
    ld e, l
    pop hl
    ld b, NAME_LENGTH
.copyGlyph
    ld a, [hli]
    ld [de], a
    inc de
    dec b
    jr nz, .copyGlyph
    ret

ListView_GetRowAddress:
    ld l, a
    ld h, 0
    REPT LIST_ROW_STRIDE_SHIFT
        add hl, hl
    ENDR
    ld de, BACKGROUND_MAP_BASE + LIST_FIRST_ROW * BACKGROUND_MAP_ROW_STRIDE
    add hl, de
    ret

ListView_DrawNames::
    ld c, 0
.drawRow
    ld a, [wListViewTop]
    add c
    ld b, a
    ld a, [wListViewCount]
    cp b
    ret z
    ret c
    ld a, c
    call ListView_GetRowAddress
    ld de, LIST_NAME_COLUMN
    add hl, de
    push hl
    ld a, b
    call ListView_GetNameAddress
    ld d, h
    ld e, l
    pop hl
    ld b, NAME_LENGTH
    call Text_PrintGlyphs
    inc c
    ld a, c
    cp LIST_VISIBLE_ROWS
    jr nz, .drawRow
    ret

ListView_RenderCursor::
    ld c, 0
.renderRow
    ld a, c
    call ListView_GetRowAddress
    ld de, LIST_CURSOR_COLUMN
    add hl, de
    ld a, [wListViewTop]
    add c
    ld b, a
    ld a, [wListViewCount]
    cp b
    jr z, .rowIsEmpty
    jr c, .rowIsEmpty
    ld a, [wListViewCursor]
    cp b
    ld a, GLYPH_SPACE
    jr nz, .writeCell
    ld a, GLYPH_CURSOR
    jr .writeCell
.rowIsEmpty
    ld a, GLYPH_SPACE
.writeCell
    ld [hl], a
    inc c
    ld a, c
    cp LIST_VISIBLE_ROWS
    jr nz, .renderRow
    ret
