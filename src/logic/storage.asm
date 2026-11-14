INCLUDE "common.inc"

SECTION "StorageState", WRAM0
wDirectory:: ds DIRECTORY_SIGNATURE_LENGTH
wDirectoryEntries:: ds DIRECTORY_ENTRIES_BYTES
wDirectoryChecksum:: ds DIRECTORY_CHECKSUM_LENGTH
wTargetSlot:: ds 1
wUsedSlotCount:: ds 1
wUsedSlotIndexes:: ds SLOT_COUNT

SECTION "Storage", ROM0

Storage_Mount::
    call Storage_LoadDirectory
    call Storage_CompareDirectorySignature
    and a
    jr nz, .formatFirstLaunch
    call Storage_VerifyDirectoryChecksum
    and a
    ret z
    call Storage_HasUsedEntry
    push af
    call Storage_FormatMirror
    call Storage_FlushDirectory
    and a
    jr nz, .reformatFailed
    pop af
    and a
    ret z
    Throw ERROR_DIRECTORY_CORRUPT
.reformatFailed
    pop bc
    ret
.formatFirstLaunch
    call Storage_FormatMirror
    jp Storage_FlushDirectory

Storage_HasUsedEntry::
    ld c, 0
.inspectSlot
    ld a, c
    call Storage_GetEntryAddress
    ld a, [hl]
    cp ENTRY_STATUS_USED
    jr z, .usedEntryFound
    inc c
    ld a, c
    cp SLOT_COUNT
    jr nz, .inspectSlot
    ld a, NO_USED_ENTRIES
    ret
.usedEntryFound
    ld a, HAS_USED_ENTRIES
    ret

Storage_ComputeDirectoryChecksum::
    ld hl, wDirectory
    ld b, DIRECTORY_CHECKSUMMED_BYTES
    ld a, DIRECTORY_CHECKSUM_SEED
.accumulateByte
    add [hl]
    inc hl
    dec b
    jr nz, .accumulateByte
    ret

Storage_VerifyDirectoryChecksum::
    call Storage_ComputeDirectoryChecksum
    ld hl, wDirectoryChecksum
    cp [hl]
    jr z, .checksumMatches
    Throw ERROR_DIRECTORY_CORRUPT
.checksumMatches
    Succeed

Storage_LoadDirectory::
    call Sram_Enable
    ld a, DIRECTORY_BANK
    call Sram_SelectBank
    ld hl, wDirectory
    ld de, SRAM_BASE_ADDRESS
    ld bc, DIRECTORY_SIZE_BYTES
    call Memory_CopyBytes
    jp Sram_Disable

Storage_CompareDirectorySignature::
    ld hl, wDirectory
    ld de, DirectorySignature
    ld b, DIRECTORY_SIGNATURE_LENGTH
    jp Memory_CompareBytes

Storage_FormatMirror::
    ld hl, wDirectory
    ld bc, DIRECTORY_SIZE_BYTES
    ld a, ENTRY_STATUS_FREE
    call Memory_FillBytes
    ld hl, wDirectory
    ld de, DirectorySignature
    ld bc, DIRECTORY_SIGNATURE_LENGTH
    jp Memory_CopyBytes

Storage_FlushDirectory::
    call Storage_ComputeDirectoryChecksum
    ld [wDirectoryChecksum], a
    call Sram_Enable
    ld a, DIRECTORY_BANK
    call Sram_SelectBank
    ld hl, SRAM_BASE_ADDRESS
    ld de, wDirectory
    ld bc, DIRECTORY_SIZE_BYTES
    call Memory_CopyBytes
    ld hl, SRAM_BASE_ADDRESS
    ld de, wDirectory
    ld b, DIRECTORY_SIZE_BYTES
    call Memory_CompareBytes
    ld b, a
    call Sram_Disable
    ld a, b
    and a
    ret z
    Throw ERROR_STORAGE_VERIFY_FAILED

Storage_GetEntryAddress::
    ld hl, wDirectoryEntries
    and a
    ret z
    ld de, DIRECTORY_ENTRY_SIZE_BYTES
    ld b, a
.advanceToNextEntry
    add hl, de
    dec b
    jr nz, .advanceToNextEntry
    ret

Storage_ClearEntry::
    call Storage_GetEntryAddress
    ld a, ENTRY_STATUS_FREE
    ld [hl], a
    ret

Storage_FindFreeSlot::
    ld c, 0
.inspectSlot
    ld a, c
    call Storage_GetEntryAddress
    ld a, [hl]
    cp ENTRY_STATUS_USED
    jr nz, .freeSlotFound
    inc c
    ld a, c
    cp SLOT_COUNT
    jr nz, .inspectSlot
    Throw ERROR_STORAGE_FULL
.freeSlotFound
    ld a, c
    ld [wTargetSlot], a
    Succeed

Storage_RebuildIndex::
    xor a
    ld [wUsedSlotCount], a
    ld c, 0
.inspectSlot
    ld a, c
    call Storage_GetEntryAddress
    ld a, [hl]
    cp ENTRY_STATUS_USED
    jr nz, .nextSlot
    ld a, [wUsedSlotCount]
    ld e, a
    ld d, 0
    ld hl, wUsedSlotIndexes
    add hl, de
    ld [hl], c
    inc a
    ld [wUsedSlotCount], a
.nextSlot
    inc c
    ld a, c
    cp SLOT_COUNT
    jr nz, .inspectSlot
    ret

Storage_CommitNewSignal::
    ld a, [wTargetSlot]
    cp SLOT_COUNT
    jr c, .slotIsValid
    Throw ERROR_INVALID_SLOT
.slotIsValid
    call Storage_GetEntryAddress
    ld a, ENTRY_STATUS_USED
    ld [hli], a
    ld de, wNameBuffer
    ld b, NAME_LENGTH
.copyNameByte
    ld a, [de]
    ld [hli], a
    inc de
    dec b
    jr nz, .copyNameByte
    call Storage_FlushDirectory
    and a
    ret z
    push af
    ld a, [wTargetSlot]
    call Storage_ClearEntry
    pop af
    ret

Storage_DeleteSlot::
    cp SLOT_COUNT
    jr c, .slotIsValid
    Throw ERROR_INVALID_SLOT
.slotIsValid
    call Storage_ClearEntry
    jp Storage_FlushDirectory

Storage_SelectSampleBank::
    add FIRST_SAMPLE_BANK
    ld b, a
    call Sram_Enable
    ld a, b
    jp Sram_SelectBank

Storage_VerifySampleSignature::
    ld a, [wTargetSlot]
    call Storage_SelectSampleBank
    ld a, [SAMPLE_SIGNATURE_ADDRESS]
    ld b, a
    call Sram_Disable
    ld a, b
    cp SAMPLE_BANK_SIGNATURE
    jr z, .signatureIntact
    Throw ERROR_SIGNAL_DAMAGED
.signatureIntact
    Succeed

Storage_ValidateName::
    call NameBuffer_CountNonSpace
    and a
    jr nz, .nameHasContent
    Throw ERROR_NAME_EMPTY
.nameHasContent
    jp Storage_CheckNameUnused

Storage_CheckNameUnused::
    ld c, 0
.inspectSlot
    ld a, c
    call Storage_GetEntryAddress
    ld a, [hli]
    cp ENTRY_STATUS_USED
    jr nz, .nextSlot
    ld de, wNameBuffer
    ld b, NAME_LENGTH
    call Memory_CompareBytes
    and a
    jr z, .nameAlreadyUsed
.nextSlot
    inc c
    ld a, c
    cp SLOT_COUNT
    jr nz, .inspectSlot
    Succeed
.nameAlreadyUsed
    Throw ERROR_NAME_IN_USE
