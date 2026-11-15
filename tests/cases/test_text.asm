INCLUDE "common.inc"
INCLUDE "test_framework.inc"

SECTION "TextTestState", WRAM0
wTextTestBuffer: ds TEST_TEXT_BUFFER_SIZE_BYTES

SECTION "TextTests", ROM0

Test_DecimalWordPrintsFiveDigits::
    ld hl, wTextTestBuffer
    ld de, TEST_DECIMAL_SAMPLE
    call Text_PrintDecimalWord
    ld a, [wTextTestBuffer]
    ExpectEqual GLYPH_DIGIT_0
    ld a, [wTextTestBuffer + 1]
    ExpectEqual GLYPH_DIGIT_0 + 1
    ld a, [wTextTestBuffer + 2]
    ExpectEqual GLYPH_DIGIT_0 + 2
    ld a, [wTextTestBuffer + 3]
    ExpectEqual GLYPH_DIGIT_0 + 3
    ld a, [wTextTestBuffer + 4]
    ExpectEqual GLYPH_DIGIT_0 + 4
    ld a, l
    ExpectEqual LOW(wTextTestBuffer + 5)
    TestPassed

Test_DecimalWordHandlesTheLimits::
    ld hl, wTextTestBuffer
    ld de, 0
    call Text_PrintDecimalWord
    ld a, [wTextTestBuffer + 4]
    ExpectEqual GLYPH_DIGIT_0
    ld hl, wTextTestBuffer
    ld de, TEST_DECIMAL_MAXIMUM
    call Text_PrintDecimalWord
    ld a, [wTextTestBuffer]
    ExpectEqual GLYPH_DIGIT_0 + 6
    ld a, [wTextTestBuffer + 1]
    ExpectEqual GLYPH_DIGIT_0 + 5
    ld a, [wTextTestBuffer + 4]
    ExpectEqual GLYPH_DIGIT_0 + 5
    TestPassed

Test_DirectoryBytesInUseCountsEntries::
    call Test_ResetWorld
    ld b, 2
    call StorageTest_CommitCards
    ExpectEqual ERROR_NONE
    xor a
    ld b, 0
    ld c, GLYPH_LETTER_A
    call StorageTest_CommitSignal
    ld a, 1
    ld b, 0
    ld c, GLYPH_LETTER_A + 1
    call StorageTest_CommitSignal
    ld a, 2
    ld b, 1
    ld c, GLYPH_LETTER_A
    call StorageTest_CommitSignal
    call Storage_RebuildCardIndex
    call Storage_ComputeDirectoryBytesInUse
    ld a, e
    ExpectEqual DIRECTORY_SIGNATURE_LENGTH + DIRECTORY_CHECKSUM_LENGTH + 2 * CARD_ENTRY_SIZE_BYTES + 3 * SIGNAL_ENTRY_SIZE_BYTES
    ld a, d
    ExpectZero
    TestPassed
