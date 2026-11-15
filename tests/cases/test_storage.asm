INCLUDE "common.inc"
INCLUDE "test_framework.inc"

SECTION "StorageTests", ROM0

StorageTest_SetSingleGlyphName:
    push af
    call NameBuffer_Clear
    pop af
    jp NameBuffer_Append

StorageTest_CommitCard::
    ld [wTargetCard], a
    ld a, c
    call StorageTest_SetSingleGlyphName
    jp Storage_CommitNewCard

StorageTest_CommitSignal::
    ld [wTargetSlot], a
    ld a, b
    ld [wTargetCard], a
    ld a, c
    call StorageTest_SetSingleGlyphName
    jp Storage_CommitNewSignal

StorageTest_CommitCards::
    ld d, 0
.commitCard
    ld a, d
    ld c, GLYPH_LETTER_A
    push bc
    push de
    call StorageTest_CommitCard
    pop de
    pop bc
    and a
    ret nz
    inc d
    ld a, d
    cp b
    jr nz, .commitCard
    Succeed

Test_MountFormatsBlankStorage::
    call Test_ResetWorld
    call Sram_Enable
    ld a, DIRECTORY_BANK
    call Sram_SelectBank
    ld hl, SRAM_BASE_ADDRESS
    ld bc, DIRECTORY_SIZE_BYTES
    ld a, TEST_BLANK_SRAM_BYTE
    call Memory_FillBytes
    ld hl, SRAM_BASE_ADDRESS + DIRECTORY_BACKUP_OFFSET
    ld bc, DIRECTORY_SIZE_BYTES
    ld a, TEST_BLANK_SRAM_BYTE
    call Memory_FillBytes
    call Sram_Disable
    call Storage_Mount
    ExpectEqual ERROR_NONE
    call Storage_CompareDirectorySignature
    ExpectZero
    call Storage_RebuildCardIndex
    ld a, [wUsedCardCount]
    ExpectZero
    TestPassed

Test_MountDetectsCorruptedDirectory::
    call Test_ResetWorld
    xor a
    ld c, GLYPH_LETTER_A
    call StorageTest_CommitCard
    ExpectEqual ERROR_NONE
    call Sram_Enable
    ld a, DIRECTORY_BANK
    call Sram_SelectBank
    ld a, GLYPH_UNDERSCORE
    ld [SRAM_BASE_ADDRESS + DIRECTORY_SIGNATURE_LENGTH + CARD_ENTRY_NAME_OFFSET], a
    ld [SRAM_BASE_ADDRESS + DIRECTORY_BACKUP_OFFSET + DIRECTORY_SIGNATURE_LENGTH + CARD_ENTRY_NAME_OFFSET], a
    call Sram_Disable
    call Test_ForgetMirror
    call Storage_Mount
    ExpectEqual ERROR_DIRECTORY_CORRUPT
    call Storage_RebuildCardIndex
    ld a, [wUsedCardCount]
    ExpectZero
    call Test_ForgetMirror
    call Storage_Mount
    ExpectEqual ERROR_NONE
    TestPassed

Test_MountRepairsEmptyCorruptedDirectorySilently::
    call Test_ResetWorld
    call Sram_Enable
    ld a, DIRECTORY_BANK
    call Sram_SelectBank
    ld a, GLYPH_UNDERSCORE
    ld [SRAM_BASE_ADDRESS + DIRECTORY_SIZE_BYTES - 1], a
    ld [SRAM_BASE_ADDRESS + DIRECTORY_BACKUP_OFFSET + DIRECTORY_SIZE_BYTES - 1], a
    call Sram_Disable
    call Test_ForgetMirror
    call Storage_Mount
    ExpectEqual ERROR_NONE
    call Test_ForgetMirror
    call Storage_Mount
    ExpectEqual ERROR_NONE
    TestPassed

Test_MountRestoresDamagedPrimaryFromBackup::
    call Test_ResetWorld
    xor a
    ld c, GLYPH_LETTER_A
    call StorageTest_CommitCard
    ExpectEqual ERROR_NONE
    call Sram_Enable
    ld a, DIRECTORY_BANK
    call Sram_SelectBank
    ld a, GLYPH_UNDERSCORE
    ld [SRAM_BASE_ADDRESS + DIRECTORY_SIGNATURE_LENGTH + CARD_ENTRY_NAME_OFFSET], a
    call Sram_Disable
    call Test_ForgetMirror
    call Storage_Mount
    ExpectEqual ERROR_NONE
    call Storage_RebuildCardIndex
    ld a, [wUsedCardCount]
    ExpectEqual 1
    ld a, [wDirectoryCards + CARD_ENTRY_NAME_OFFSET]
    ExpectEqual GLYPH_LETTER_A
    call Test_ForgetMirror
    call Storage_Mount
    ExpectEqual ERROR_NONE
    ld a, [wDirectoryPrimaryClass]
    ExpectEqual DIRECTORY_VALID
    TestPassed

Test_CardPersistsAcrossReboot::
    call Test_ResetWorld
    xor a
    ld c, GLYPH_LETTER_A
    call StorageTest_CommitCard
    ExpectEqual ERROR_NONE
    call Test_ForgetMirror
    call Storage_Mount
    ExpectEqual ERROR_NONE
    call Storage_RebuildCardIndex
    ld a, [wUsedCardCount]
    ExpectEqual 1
    ld a, [wDirectoryCards + CARD_ENTRY_NAME_OFFSET]
    ExpectEqual GLYPH_LETTER_A
    TestPassed

Test_SignalPersistsAcrossReboot::
    call Test_ResetWorld
    xor a
    ld c, GLYPH_LETTER_A
    call StorageTest_CommitCard
    ExpectEqual ERROR_NONE
    xor a
    ld b, 0
    ld c, GLYPH_LETTER_A + 1
    call StorageTest_CommitSignal
    ExpectEqual ERROR_NONE
    call Test_ForgetMirror
    call Storage_Mount
    ExpectEqual ERROR_NONE
    xor a
    call Storage_RebuildSignalIndex
    ld a, [wCardSignalCount]
    ExpectEqual 1
    ld a, [wDirectorySignals + SIGNAL_ENTRY_NAME_OFFSET]
    ExpectEqual GLYPH_LETTER_A + 1
    ld a, [wDirectorySignals + SIGNAL_ENTRY_CARD_OFFSET]
    ExpectZero
    TestPassed

Test_CardNameMustBeUnique::
    call Test_ResetWorld
    xor a
    ld c, GLYPH_LETTER_A
    call StorageTest_CommitCard
    ExpectEqual ERROR_NONE
    ld a, GLYPH_LETTER_A
    call StorageTest_SetSingleGlyphName
    call Storage_ValidateCardName
    ExpectEqual ERROR_CARD_NAME_IN_USE
    ld a, GLYPH_LETTER_A + 1
    call StorageTest_SetSingleGlyphName
    call Storage_ValidateCardName
    ExpectEqual ERROR_NONE
    call NameBuffer_Clear
    call Storage_ValidateCardName
    ExpectEqual ERROR_NAME_EMPTY
    ld a, GLYPH_SPACE
    call NameBuffer_Append
    call Storage_ValidateSignalName
    ExpectEqual ERROR_NAME_EMPTY
    TestPassed

Test_SignalNameIsUniqueWithinCardOnly::
    call Test_ResetWorld
    ld b, 2
    call StorageTest_CommitCards
    ExpectEqual ERROR_NONE
    xor a
    ld b, 0
    ld c, GLYPH_LETTER_A + 23
    call StorageTest_CommitSignal
    ExpectEqual ERROR_NONE
    xor a
    ld [wTargetCard], a
    ld a, GLYPH_LETTER_A + 23
    call StorageTest_SetSingleGlyphName
    call Storage_ValidateSignalName
    ExpectEqual ERROR_SIGNAL_NAME_IN_USE
    ld a, 1
    ld [wTargetCard], a
    ld a, GLYPH_LETTER_A + 23
    call StorageTest_SetSingleGlyphName
    call Storage_ValidateSignalName
    ExpectEqual ERROR_NONE
    TestPassed

Test_CardListFillsUpAtThirtyTwo::
    call Test_ResetWorld
    call Storage_FindFreeCard
    ExpectEqual ERROR_NONE
    ld a, [wTargetCard]
    ExpectZero
    ld b, CARD_COUNT_MAX
    call StorageTest_CommitCards
    ExpectEqual ERROR_NONE
    call Storage_FindFreeCard
    ExpectEqual ERROR_CARD_LIST_FULL
    TestPassed

Test_CardAcceptsEightSignalsAndRejectsNinth::
    call Test_ResetWorld
    ld b, 2
    call StorageTest_CommitCards
    ExpectEqual ERROR_NONE
    ld d, 0
.commitSignal
    ld a, d
    ld b, 0
    ld c, GLYPH_LETTER_A
    push de
    call StorageTest_CommitSignal
    pop de
    ExpectEqual ERROR_NONE
    inc d
    ld a, d
    cp SIGNALS_PER_CARD_MAX
    jr nz, .commitSignal
    xor a
    ld [wTargetCard], a
    call Storage_CheckCardHasRoom
    ExpectEqual ERROR_CARD_FULL
    ld a, 1
    ld [wTargetCard], a
    call Storage_CheckCardHasRoom
    ExpectEqual ERROR_NONE
    TestPassed

Test_SignalPoolRunsOutAtThirty::
    call Test_ResetWorld
    ld b, TEST_CARDS_FOR_FULL_POOL
    call StorageTest_CommitCards
    ExpectEqual ERROR_NONE
    ld d, 0
.commitSignal
    ld a, d
    REPT TEST_SIGNALS_PER_CARD_SHIFT
        srl a
    ENDR
    ld b, a
    ld a, d
    ld c, GLYPH_LETTER_A
    push de
    call StorageTest_CommitSignal
    pop de
    ExpectEqual ERROR_NONE
    inc d
    ld a, d
    cp SIGNAL_SLOT_COUNT
    jr nz, .commitSignal
    call Storage_FindFreeSignalSlot
    ExpectEqual ERROR_STORAGE_FULL
    TestPassed

Test_DeleteSignalFreesSlot::
    call Test_ResetWorld
    ld b, 1
    call StorageTest_CommitCards
    ExpectEqual ERROR_NONE
    xor a
    ld b, 0
    ld c, GLYPH_LETTER_A + 1
    call StorageTest_CommitSignal
    ExpectEqual ERROR_NONE
    xor a
    call Storage_DeleteSignal
    ExpectEqual ERROR_NONE
    xor a
    call Storage_RebuildSignalIndex
    ld a, [wCardSignalCount]
    ExpectZero
    call Storage_FindFreeSignalSlot
    ExpectEqual ERROR_NONE
    ld a, [wTargetSlot]
    ExpectZero
    TestPassed

Test_DeleteCardRemovesItsSignals::
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
    ExpectEqual ERROR_NONE
    xor a
    call Storage_DeleteCard
    ExpectEqual ERROR_NONE
    call Test_ForgetMirror
    call Storage_Mount
    ExpectEqual ERROR_NONE
    call Storage_RebuildCardIndex
    ld a, [wUsedCardCount]
    ExpectEqual 1
    xor a
    call Storage_RebuildSignalIndex
    ld a, [wCardSignalCount]
    ExpectZero
    ld a, 1
    call Storage_RebuildSignalIndex
    ld a, [wCardSignalCount]
    ExpectEqual 1
    ld a, [wCardSignalIndexes]
    ExpectEqual 2
    TestPassed

Test_InvalidIndicesAreRejected::
    call Test_ResetWorld
    ld a, CARD_COUNT_MAX
    call Storage_DeleteCard
    ExpectEqual ERROR_INVALID_CARD
    ld a, SIGNAL_SLOT_COUNT
    call Storage_DeleteSignal
    ExpectEqual ERROR_INVALID_SIGNAL
    ld a, CARD_COUNT_MAX
    ld c, GLYPH_LETTER_A
    call StorageTest_CommitCard
    ExpectEqual ERROR_INVALID_CARD
    ld a, SIGNAL_SLOT_COUNT
    ld b, 0
    ld c, GLYPH_LETTER_A
    call StorageTest_CommitSignal
    ExpectEqual ERROR_INVALID_SIGNAL
    TestPassed

Test_UsedSignalsAreCounted::
    call Test_ResetWorld
    call Storage_CountUsedSignals
    ExpectZero
    ld b, 1
    call StorageTest_CommitCards
    ExpectEqual ERROR_NONE
    xor a
    ld b, 0
    ld c, GLYPH_LETTER_A
    call StorageTest_CommitSignal
    ld a, 4
    ld b, 0
    ld c, GLYPH_LETTER_A + 1
    call StorageTest_CommitSignal
    call Storage_CountUsedSignals
    ExpectEqual 2
    TestPassed

Test_CardIndexListsUsedCardsInOrder::
    call Test_ResetWorld
    ld a, 3
    ld c, GLYPH_LETTER_A
    call StorageTest_CommitCard
    ld a, 1
    ld c, GLYPH_LETTER_A + 1
    call StorageTest_CommitCard
    call Storage_RebuildCardIndex
    ld a, [wUsedCardCount]
    ExpectEqual 2
    ld a, [wUsedCardIndexes]
    ExpectEqual 1
    ld a, [wUsedCardIndexes + 1]
    ExpectEqual 3
    TestPassed

Test_CommitCardWithSignalStoresBoth::
    call Test_ResetWorld
    ld a, 2
    ld [wTargetCard], a
    ld a, 5
    ld [wTargetSlot], a
    ld a, GLYPH_LETTER_A
    ld [wPendingCardName], a
    ld a, GLYPH_LETTER_A + 1
    call StorageTest_SetSingleGlyphName
    call Storage_CommitNewCardWithSignal
    ExpectEqual ERROR_NONE
    call Test_ForgetMirror
    call Storage_Mount
    ExpectEqual ERROR_NONE
    call Storage_RebuildCardIndex
    ld a, [wUsedCardCount]
    ExpectEqual 1
    ld a, [wUsedCardIndexes]
    ExpectEqual 2
    ld a, 2
    call Storage_RebuildSignalIndex
    ld a, [wCardSignalCount]
    ExpectEqual 1
    ld a, [wCardSignalIndexes]
    ExpectEqual 5
    TestPassed

Test_SampleSlotsDoNotOverlap::
    call Test_ResetWorld
    xor a
    ld [wTargetSlot], a
    ld a, TEST_PATTERN_SLOT_ZERO
    call Test_FillSampleBuffer
    call Storage_SaveSampleFromBuffer
    ExpectEqual ERROR_NONE
    ld a, 1
    ld [wTargetSlot], a
    ld a, TEST_PATTERN_SLOT_ONE
    call Test_FillSampleBuffer
    call Storage_SaveSampleFromBuffer
    ExpectEqual ERROR_NONE
    ld a, 2
    ld [wTargetSlot], a
    ld a, TEST_PATTERN_SLOT_TWO
    call Test_FillSampleBuffer
    call Storage_SaveSampleFromBuffer
    ExpectEqual ERROR_NONE
    xor a
    ld [wTargetSlot], a
    ld a, TEST_BLANK_SRAM_BYTE
    call Test_FillSampleBuffer
    call Storage_LoadSampleToBuffer
    ExpectEqual ERROR_NONE
    ld a, [wSampleBuffer]
    ExpectEqual TEST_PATTERN_SLOT_ZERO
    ld a, [wSampleBuffer + SAMPLE_BUFFER_SIZE_BYTES - 1]
    ExpectEqual TEST_PATTERN_SLOT_ZERO
    ld a, 1
    ld [wTargetSlot], a
    call Storage_LoadSampleToBuffer
    ExpectEqual ERROR_NONE
    ld a, [wSampleBuffer]
    ExpectEqual TEST_PATTERN_SLOT_ONE
    ld a, [wSampleBuffer + SAMPLE_BUFFER_SIZE_BYTES - 1]
    ExpectEqual TEST_PATTERN_SLOT_ONE
    ld a, 2
    ld [wTargetSlot], a
    call Storage_LoadSampleToBuffer
    ExpectEqual ERROR_NONE
    ld a, [wSampleBuffer]
    ExpectEqual TEST_PATTERN_SLOT_TWO
    TestPassed

Test_SampleSignatureIsPerSlot::
    call Test_ResetWorld
    xor a
    ld [wTargetSlot], a
    ld a, TEST_PATTERN_SLOT_ZERO
    call Test_FillSampleBuffer
    call Storage_SaveSampleFromBuffer
    ld a, 1
    ld [wTargetSlot], a
    call Storage_SaveSampleFromBuffer
    ExpectEqual ERROR_NONE
    ld a, 1
    call Storage_SelectSampleSlot
    ld de, SLOT_SIGNATURE_OFFSET
    add hl, de
    ld a, TEST_BLANK_SRAM_BYTE
    ld [hl], a
    call Sram_Disable
    xor a
    ld [wTargetSlot], a
    call Storage_VerifySampleSignature
    ExpectEqual ERROR_NONE
    ld a, 1
    ld [wTargetSlot], a
    call Storage_VerifySampleSignature
    ExpectEqual ERROR_SIGNAL_DAMAGED
    call Storage_LoadSampleToBuffer
    ExpectEqual ERROR_SIGNAL_DAMAGED
    TestPassed

Test_SampleRoundTripsThroughSram::
    call Test_ResetWorld
    xor a
    ld [wTargetSlot], a
    ld a, TEST_SAMPLE_FILL_BYTE
    call Test_FillSampleBuffer
    ld a, TEST_SAMPLE_FIRST_BYTE
    ld [wSampleBuffer], a
    ld a, TEST_SAMPLE_LAST_BYTE
    ld [wSampleBuffer + SAMPLE_BUFFER_SIZE_BYTES - 1], a
    call Storage_SaveSampleFromBuffer
    ExpectEqual ERROR_NONE
    ld a, TEST_BLANK_SRAM_BYTE
    call Test_FillSampleBuffer
    call Storage_LoadSampleToBuffer
    ExpectEqual ERROR_NONE
    ld a, [wSampleBuffer]
    ExpectEqual TEST_SAMPLE_FIRST_BYTE
    ld a, [wSampleBuffer + SAMPLE_BUFFER_SIZE_BYTES / 2]
    ExpectEqual TEST_SAMPLE_FILL_BYTE
    ld a, [wSampleBuffer + SAMPLE_BUFFER_SIZE_BYTES - 1]
    ExpectEqual TEST_SAMPLE_LAST_BYTE
    TestPassed
