INCLUDE "common.inc"

SECTION "EventLogState", WRAM0
wBootCounter:: ds 2
wLogScratchIndex: ds 1

SECTION "EventLog", ROM0

EventLog_Initialise::
    call Sram_Enable
    xor a
    call Sram_SelectBank
    ld hl, LOG_BASE_ADDRESS
    ld de, LogMagic
    ld b, LOG_MAGIC_LENGTH
    call Memory_CompareBytes
    and a
    jr z, .logIsInitialised
    ld hl, LOG_BASE_ADDRESS
    ld bc, LOG_SIZE_BYTES
    xor a
    call Memory_FillBytes
    ld hl, LOG_BASE_ADDRESS
    ld de, LogMagic
    ld bc, LOG_MAGIC_LENGTH
    call Memory_CopyBytes
.logIsInitialised
    ld hl, LOG_BASE_ADDRESS + LOG_BOOT_COUNTER_OFFSET
    ld a, [hli]
    ld e, a
    ld a, [hl]
    ld d, a
    inc de
    ld a, d
    ld [hld], a
    ld a, e
    ld [hl], a
    ld a, e
    ld [wBootCounter], a
    ld a, d
    ld [wBootCounter + 1], a
    jp Sram_Disable

EventLog_Append::
    ld c, a
    call Sram_Enable
    xor a
    call Sram_SelectBank
    ld a, [LOG_BASE_ADDRESS + LOG_INDEX_OFFSET]
    cp LOG_ENTRY_COUNT
    jr c, .indexInRange
    xor a
.indexInRange
    ld [wLogScratchIndex], a
    ld h, 0
    ld l, a
    add hl, hl
    add hl, hl
    ld de, LOG_ENTRY_ADDRESS
    add hl, de
    ld a, c
    ld [hli], a
    ld a, b
    ld [hli], a
    ld a, [wBootCounter]
    ld [hli], a
    ld a, [wBootCounter + 1]
    ld [hl], a
    ld a, [wLogScratchIndex]
    inc a
    cp LOG_ENTRY_COUNT
    jr c, .storeIndex
    xor a
.storeIndex
    ld [LOG_BASE_ADDRESS + LOG_INDEX_OFFSET], a
    jp Sram_Disable

EventLog_RecordBootFacts::
    ld a, [wSramBankCount]
    ld b, a
    ld a, EVENT_BOOT
    call EventLog_Append
    ld a, [wSramProbeKept]
    and a
    ld a, [wSramBankCount]
    jr z, .probeNotKept
    or PROBE_KEPT_FLAG
.probeNotKept
    ld b, a
    ld a, EVENT_PROBE
    jp EventLog_Append

EventLog_RecordMountResult::
    ld a, [wDirectoryPrimaryClass]
    swap a
    ld b, a
    ld a, [wDirectoryBackupClass]
    or b
    ld b, a
    ld a, EVENT_MOUNT
    jp EventLog_Append
