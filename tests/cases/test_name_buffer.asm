INCLUDE "common.inc"
INCLUDE "test_framework.inc"

SECTION "NameBufferTests", ROM0

Test_ClearEmptiesBuffer::
    ld a, GLYPH_LETTER_A
    call NameBuffer_Append
    call NameBuffer_Clear
    ld a, [wNameLength]
    ExpectZero
    ld a, [wNameBuffer]
    ExpectEqual GLYPH_SPACE
    TestPassed

Test_AppendStoresGlyphsInOrder::
    call NameBuffer_Clear
    ld a, GLYPH_LETTER_A
    call NameBuffer_Append
    ld a, GLYPH_LETTER_A + 1
    call NameBuffer_Append
    ld a, [wNameLength]
    ExpectEqual 2
    ld a, [wNameBuffer]
    ExpectEqual GLYPH_LETTER_A
    ld a, [wNameBuffer + 1]
    ExpectEqual GLYPH_LETTER_A + 1
    TestPassed

Test_AppendIgnoresOverflow::
    call NameBuffer_Clear
    ld c, NAME_LENGTH + 3
.appendGlyph
    ld a, GLYPH_DIGIT_0
    call NameBuffer_Append
    dec c
    jr nz, .appendGlyph
    ld a, [wNameLength]
    ExpectEqual NAME_LENGTH
    ld a, [wNameBuffer + NAME_LENGTH - 1]
    ExpectEqual GLYPH_DIGIT_0
    TestPassed

Test_RemoveLastShortensName::
    call NameBuffer_Clear
    ld a, GLYPH_LETTER_A
    call NameBuffer_Append
    ld a, GLYPH_LETTER_A + 1
    call NameBuffer_Append
    call NameBuffer_RemoveLast
    ld a, [wNameLength]
    ExpectEqual 1
    ld a, [wNameBuffer + 1]
    ExpectEqual GLYPH_SPACE
    TestPassed

Test_RemoveLastOnEmptyIsHarmless::
    call NameBuffer_Clear
    call NameBuffer_RemoveLast
    ld a, [wNameLength]
    ExpectZero
    TestPassed

Test_CountNonSpaceIgnoresSpaces::
    call NameBuffer_Clear
    ld a, GLYPH_LETTER_A
    call NameBuffer_Append
    ld a, GLYPH_SPACE
    call NameBuffer_Append
    ld a, GLYPH_LETTER_A + 1
    call NameBuffer_Append
    call NameBuffer_CountNonSpace
    ExpectEqual 2
    TestPassed
