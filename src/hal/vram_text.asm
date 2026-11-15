INCLUDE "common.inc"

SECTION "VramTextState", WRAM0
wDecimalDigit: ds 1

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

Text_PrintDecimalWord::
    ld bc, 10000
    call Text_PrintDecimalPlace
    ld bc, 1000
    call Text_PrintDecimalPlace
    ld bc, 100
    call Text_PrintDecimalPlace
    ld bc, 10
    call Text_PrintDecimalPlace
    ld a, e
    add GLYPH_DIGIT_0
    ld [hli], a
    ret

Text_PrintDecimalPlace:
    ld a, GLYPH_DIGIT_0
    ld [wDecimalDigit], a
.subtractPlace
    ld a, d
    cp b
    jr c, .placeDone
    jr nz, .subtract
    ld a, e
    cp c
    jr c, .placeDone
.subtract
    ld a, e
    sub c
    ld e, a
    ld a, d
    sbc b
    ld d, a
    ld a, [wDecimalDigit]
    inc a
    ld [wDecimalDigit], a
    jr .subtractPlace
.placeDone
    ld a, [wDecimalDigit]
    ld [hli], a
    ret
