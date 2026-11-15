INCLUDE "common.inc"
INCLUDE "test_framework.inc"

SECTION "EventLogTests", ROM0

EventLogTest_WipeLog:
    call Sram_Enable
    xor a
    call Sram_SelectBank
    ld hl, LOG_BASE_ADDRESS
    ld bc, LOG_SIZE_BYTES
    ld a, TEST_BLANK_SRAM_BYTE
    call Memory_FillBytes
    jp Sram_Disable

Test_LogInitialisationCountsBoots::
    call EventLogTest_WipeLog
    call EventLog_Initialise
    ld a, [wBootCounter]
    ExpectEqual 1
    call EventLog_Initialise
    ld a, [wBootCounter]
    ExpectEqual 2
    ld a, [wBootCounter + 1]
    ExpectZero
    TestPassed

Test_LogAppendStoresTheEntry::
    call EventLogTest_WipeLog
    call EventLog_Initialise
    ld a, EVENT_ERROR
    ld b, ERROR_CARD_FULL
    call EventLog_Append
    call Sram_Enable
    xor a
    call Sram_SelectBank
    ld a, [LOG_ENTRY_ADDRESS]
    ExpectEqual EVENT_ERROR
    ld a, [LOG_ENTRY_ADDRESS + 1]
    ExpectEqual ERROR_CARD_FULL
    ld a, [LOG_ENTRY_ADDRESS + 2]
    ExpectEqual 1
    ld a, [LOG_BASE_ADDRESS + LOG_INDEX_OFFSET]
    ExpectEqual 1
    call Sram_Disable
    TestPassed

Test_LogWrapsAroundAndKeepsTheNewest::
    call EventLogTest_WipeLog
    call EventLog_Initialise
    ld bc, LOG_ENTRY_COUNT + TEST_LOG_EXTRA_EVENTS
    ld d, 0
.appendEvent
    push bc
    push de
    ld a, EVENT_SAVE
    ld b, d
    call EventLog_Append
    pop de
    pop bc
    inc d
    dec bc
    ld a, b
    or c
    jr nz, .appendEvent
    call Sram_Enable
    xor a
    call Sram_SelectBank
    ld a, [LOG_BASE_ADDRESS + LOG_INDEX_OFFSET]
    ExpectEqual TEST_LOG_EXTRA_EVENTS
    ld a, [LOG_ENTRY_ADDRESS + 1]
    ExpectEqual LOG_ENTRY_COUNT
    ld a, [LOG_ENTRY_ADDRESS + LOG_ENTRY_SIZE_BYTES + 1]
    ExpectEqual LOG_ENTRY_COUNT + 1
    ld a, [LOG_ENTRY_ADDRESS + TEST_LOG_EXTRA_EVENTS * LOG_ENTRY_SIZE_BYTES + 1]
    ExpectEqual TEST_LOG_EXTRA_EVENTS
    call Sram_Disable
    TestPassed

Test_LogRecordsTheMountClasses::
    call EventLogTest_WipeLog
    call EventLog_Initialise
    ld a, DIRECTORY_DAMAGED
    ld [wDirectoryPrimaryClass], a
    ld a, DIRECTORY_VALID
    ld [wDirectoryBackupClass], a
    call EventLog_RecordMountResult
    call Sram_Enable
    xor a
    call Sram_SelectBank
    ld a, [LOG_ENTRY_ADDRESS]
    ExpectEqual EVENT_MOUNT
    ld a, [LOG_ENTRY_ADDRESS + 1]
    ExpectEqual (DIRECTORY_DAMAGED << MOUNT_PRIMARY_SHIFT) | DIRECTORY_VALID
    call Sram_Disable
    TestPassed

Test_LogRegionDoesNotOverlapTheDirectory::
    call Test_ResetWorld
    call EventLogTest_WipeLog
    call EventLog_Initialise
    xor a
    ld c, GLYPH_LETTER_A
    call StorageTest_CommitCard
    ExpectEqual ERROR_NONE
    call Test_ForgetMirror
    call Storage_Mount
    ExpectEqual ERROR_NONE
    call EventLog_Initialise
    ld a, [wBootCounter]
    ExpectEqual 2
    TestPassed
