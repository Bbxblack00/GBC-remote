INCLUDE "common.inc"

SECTION "VramText", ROM0

Text_PrintString::
.printGlyph
    ld a, [de]
    cp STRING_END
    ret z
    ld [hli], a
    inc de
    jr .printGlyph

Text_PrintGlyphs::
.copyGlyph
    ld a, [de]
    ld [hli], a
    inc de
    dec b
    jr nz, .copyGlyph
    ret

Text_PrintDecimalByte::
    ld b, 0
.countTens
    cp 10
    jr c, .tensCounted
    sub 10
    inc b
    jr .countTens
.tensCounted
    ld c, a
    ld a, b
    add GLYPH_DIGIT_0
    ld [hli], a
    ld a, c
    add GLYPH_DIGIT_0
    ld [hli], a
    ret
