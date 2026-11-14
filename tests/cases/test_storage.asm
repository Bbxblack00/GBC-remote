INCLUDE "common.inc"
INCLUDE "test_framework.inc"

SECTION "StorageTests", ROM0

StorageTest_SetSingleGlyphName:
    push af
    call NameBuffer_Clear
    pop af
    jp NameBuffer_Append

StorageTest_CommitSingleGlyphName:
    call StorageTest_SetSingleGlyphName
    jp Storage_CommitNewSignal

StorageTest_CommitInSlot:
    ld [wTargetSlot], a
    ld a, GLYPH_LETTER_A
    jp StorageTest_CommitSingleGlyphName

Test_MountFormatsBlankStorage::
    call Test_ResetWorld
    call Sram_Enable
    ld a, DIRECTORY_BANK
    call Sram_SelectBank
    ld hl, SRAM_BASE_ADDRESS
    ld bc, DIRECTORY_SIZE_BYTES
    ld a, TEST_BLANK_SRAM_BYTE
    call Memory_FillBytes
    call Sram_Disable
    call Storage_Mount
    ExpectEqual ERROR_NONE
    call Storage_CompareDirectorySignature
    ExpectZero
    call Storage_RebuildIndex
    ld a, [wUsedSlotCount]
    ExpectZero
    TestPassed

Test_MountDetectsCorruptedDirectory::
    call Test_ResetWorld
    xor a
    call StorageTest_CommitInSlot
    ExpectEqual ERROR_NONE
    call Sram_Enable
    ld a, DIRECTORY_BANK
    call Sram_SelectBank
    ld a, GLYPH_UNDERSCORE
    ld [SRAM_BASE_ADDRESS + DIRECTORY_SIGNATURE_LENGTH + 1], a
    call Sram_Disable
    call Test_ForgetMirror
    call Storage_Mount
    ExpectEqual ERROR_DIRECTORY_CORRUPT
    call Storage_RebuildIndex
    ld a, [wUsedSlotCount]
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
    call Sram_Disable
    call Test_ForgetMirror
    call Storage_Mount
    ExpectEqual ERROR_NONE
    call Test_ForgetMirror
    call Storage_Mount
    ExpectEqual ERROR_NONE
    TestPassed

Test_CommitPersistsAcrossReboot::
    call Test_ResetWorld
    xor a
    call StorageTest_CommitInSlot
    ExpectEqual ERROR_NONE
    call Test_ForgetMirror
    call Storage_Mount
    ExpectEqual ERROR_NONE
    call Storage_RebuildIndex
    ld a, [wUsedSlotCount]
    ExpectEqual 1
    ld a, [wDirectoryEntries + 1]
    ExpectEqual GLYPH_LETTER_A
    TestPassed

Test_DuplicateNameIsRejected::
    call Test_ResetWorld
    xor a
    call StorageTest_CommitInSlot
    ExpectEqual ERROR_NONE
    ld a, GLYPH_LETTER_A
    call StorageTest_SetSingleGlyphName
    call Storage_ValidateName
    ExpectEqual ERROR_NAME_IN_USE
    ld a, GLYPH_LETTER_A + 1
    call StorageTest_SetSingleGlyphName
    call Storage_ValidateName
    ExpectEqual ERROR_NONE
    TestPassed

Test_BlankNameIsRejected::
    call Test_ResetWorld
    call Storage_ValidateName
    ExpectEqual ERROR_NAME_EMPTY
    ld a, GLYPH_SPACE
    call NameBuffer_Append
    call Storage_ValidateName
    ExpectEqual ERROR_NAME_EMPTY
    TestPassed

Test_FullStorageIsReported::
    call Test_ResetWorld
    ld c, 0
.commitSlot
    ld a, c
    ld [wTargetSlot], a
    ld a, GLYPH_LETTER_A
    add c
    push bc
    call StorageTest_CommitSingleGlyphName
    pop bc
    ExpectEqual ERROR_NONE
    inc c
    ld a, c
    cp SLOT_COUNT
    jr nz, .commitSlot
    call Storage_FindFreeSlot
    ExpectEqual ERROR_STORAGE_FULL
    TestPassed

Test_FindFreeSlotPicksLowestFree::
    call Test_ResetWorld
    call Storage_FindFreeSlot
    ExpectEqual ERROR_NONE
    ld a, [wTargetSlot]
    ExpectZero
    xor a
    call StorageTest_CommitInSlot
    call Storage_FindFreeSlot
    ExpectEqual ERROR_NONE
    ld a, [wTargetSlot]
    ExpectEqual 1
    TestPassed

Test_DeleteFreesSlotAndName::
    call Test_ResetWorld
    xor a
    call StorageTest_CommitInSlot
    xor a
    call Storage_DeleteSlot
    ExpectEqual ERROR_NONE
    call Storage_RebuildIndex
    ld a, [wUsedSlotCount]
    ExpectZero
    ld a, GLYPH_LETTER_A
    call StorageTest_SetSingleGlyphName
    call Storage_ValidateName
    ExpectEqual ERROR_NONE
    TestPassed

Test_DeletePersistsAcrossReboot::
    call Test_ResetWorld
    xor a
    call StorageTest_CommitInSlot
    xor a
    call Storage_DeleteSlot
    call Test_ForgetMirror
    call Storage_Mount
    call Storage_RebuildIndex
    ld a, [wUsedSlotCount]
    ExpectZero
    TestPassed

Test_InvalidSlotIsRejected::
    call Test_ResetWorld
    ld a, SLOT_COUNT
    call Storage_DeleteSlot
    ExpectEqual ERROR_INVALID_SLOT
    ld a, SLOT_COUNT
    call StorageTest_CommitInSlot
    ExpectEqual ERROR_INVALID_SLOT
    TestPassed

Test_IndexListsUsedSlotsInOrder::
    call Test_ResetWorld
    ld a, 3
    call StorageTest_CommitInSlot
    ld a, 1
    ld [wTargetSlot], a
    ld a, GLYPH_LETTER_A + 1
    call StorageTest_CommitSingleGlyphName
    call Storage_RebuildIndex
    ld a, [wUsedSlotCount]
    ExpectEqual 2
    ld a, [wUsedSlotIndexes]
    ExpectEqual 1
    ld a, [wUsedSlotIndexes + 1]
    ExpectEqual 3
    TestPassed

Test_SampleSignatureDetectsDamage::
    call Test_ResetWorld
    xor a
    ld [wTargetSlot], a
    call Storage_SelectSampleBank
    ld a, SAMPLE_BANK_SIGNATURE
    ld [SAMPLE_SIGNATURE_ADDRESS], a
    call Sram_Disable
    call Storage_VerifySampleSignature
    ExpectEqual ERROR_NONE
    xor a
    call Storage_SelectSampleBank
    ld a, TEST_BLANK_SRAM_BYTE
    ld [SAMPLE_SIGNATURE_ADDRESS], a
    call Sram_Disable
    call Storage_VerifySampleSignature
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

Test_LoadReportsDamagedSample::
    call Test_ResetWorld
    xor a
    ld [wTargetSlot], a
    call Storage_SelectSampleBank
    ld a, TEST_BLANK_SRAM_BYTE
    ld [SAMPLE_SIGNATURE_ADDRESS], a
    call Sram_Disable
    call Storage_LoadSampleToBuffer
    ExpectEqual ERROR_SIGNAL_DAMAGED
    TestPassed
