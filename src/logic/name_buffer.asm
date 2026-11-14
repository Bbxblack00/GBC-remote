INCLUDE "common.inc"

SECTION "NameBufferState", WRAM0
wNameBuffer:: ds NAME_LENGTH
wNameLength:: ds 1

SECTION "NameBuffer", ROM0

NameBuffer_Clear::
    ld hl, wNameBuffer
    ld bc, NAME_LENGTH
    ld a, GLYPH_SPACE
    call Memory_FillBytes
    xor a
    ld [wNameLength], a
    ret

NameBuffer_Append::
    ld b, a
    ld a, [wNameLength]
    cp NAME_LENGTH
    ret nc
    ld e, a
    ld d, 0
    ld hl, wNameBuffer
    add hl, de
    ld [hl], b
    inc a
    ld [wNameLength], a
    ret

NameBuffer_RemoveLast::
    ld a, [wNameLength]
    and a
    ret z
    dec a
    ld [wNameLength], a
    ld e, a
    ld d, 0
    ld hl, wNameBuffer
    add hl, de
    ld a, GLYPH_SPACE
    ld [hl], a
    ret

NameBuffer_CountNonSpace::
    ld hl, wNameBuffer
    ld b, NAME_LENGTH
    ld c, 0
.inspectGlyph
    ld a, [hli]
    cp GLYPH_SPACE
    jr z, .nextGlyph
    inc c
.nextGlyph
    dec b
    jr nz, .inspectGlyph
    ld a, c
    ret
