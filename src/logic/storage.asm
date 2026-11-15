INCLUDE "common.inc"

SECTION "StorageState", WRAM0
wDirectory:: ds DIRECTORY_SIGNATURE_LENGTH
wDirectoryCards:: ds DIRECTORY_CARDS_BYTES
wDirectorySignals:: ds DIRECTORY_SIGNALS_BYTES
wDirectoryChecksum:: ds DIRECTORY_CHECKSUM_LENGTH
wTargetSlot:: ds 1
wTargetCard:: ds 1
wSelectedCard:: ds 1
wUsedCardCount:: ds 1
wUsedCardIndexes:: ds CARD_COUNT_MAX
wCardSignalCount:: ds 1
wCardSignalIndexes:: ds SIGNALS_PER_CARD_MAX
wPendingCardName:: ds NAME_LENGTH
wDirectoryPrimaryClass:: ds 1
wDirectoryBackupClass:: ds 1

SECTION "Storage", ROM0

Storage_Mount::
    ld hl, SRAM_BASE_ADDRESS
    call Storage_LoadDirectoryAt
    call Storage_ClassifyMirror
    ld [wDirectoryPrimaryClass], a
    and a
    ret z
    ld hl, SRAM_BASE_ADDRESS + DIRECTORY_BACKUP_OFFSET
    call Storage_LoadDirectoryAt
    call Storage_ClassifyMirror
    ld [wDirectoryBackupClass], a
    and a
    jr nz, .bothCopiesUnusable
    jp Storage_FlushDirectory
.bothCopiesUnusable
    ld a, [wDirectoryPrimaryClass]
    cp DIRECTORY_DAMAGED
    jr nz, .primaryNotDamaged
    ld hl, SRAM_BASE_ADDRESS
    call Storage_LoadDirectoryAt
    jr .examineDamagedDirectory
.primaryNotDamaged
    ld a, [wDirectoryBackupClass]
    cp DIRECTORY_DAMAGED
    jr nz, .formatFirstLaunch
.examineDamagedDirectory
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

Storage_ClassifyMirror::
    call Storage_CompareDirectorySignature
    and a
    jr z, .signatureMatches
    ld a, DIRECTORY_UNFORMATTED
    ret
.signatureMatches
    call Storage_VerifyDirectoryChecksum
    and a
    ret z
    ld a, DIRECTORY_DAMAGED
    ret

Storage_HasUsedEntry::
    ld c, 0
.inspectCard
    ld a, c
    call Storage_GetCardEntryAddress
    ld a, [hl]
    cp ENTRY_STATUS_USED
    jr z, .usedEntryFound
    inc c
    ld a, c
    cp CARD_COUNT_MAX
    jr nz, .inspectCard
    ld a, NO_USED_ENTRIES
    ret
.usedEntryFound
    ld a, HAS_USED_ENTRIES
    ret

Storage_ComputeDirectoryChecksum::
    ld hl, wDirectory
    ld bc, DIRECTORY_CHECKSUMMED_BYTES
    ld a, DIRECTORY_CHECKSUM_SEED
.accumulateByte
    add [hl]
    inc hl
    dec bc
    ld d, a
    ld a, b
    or c
    ld a, d
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

Storage_LoadDirectoryAt::
    push hl
    call Sram_Enable
    ld a, DIRECTORY_BANK
    call Sram_SelectBank
    pop de
    ld hl, wDirectory
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
    call Storage_WriteAndVerifyDirectoryCopy
    ld b, a
    and a
    jr nz, .copiesWritten
    ld hl, SRAM_BASE_ADDRESS + DIRECTORY_BACKUP_OFFSET
    call Storage_WriteAndVerifyDirectoryCopy
    ld b, a
.copiesWritten
    call Sram_Disable
    ld a, b
    and a
    ret z
    Throw ERROR_STORAGE_VERIFY_FAILED

Storage_WriteAndVerifyDirectoryCopy:
    push hl
    ld de, wDirectory
    ld bc, DIRECTORY_SIZE_BYTES
    call Memory_CopyBytes
    pop hl
    ld de, wDirectory
    ld bc, DIRECTORY_SIZE_BYTES
    jp Memory_CompareBlock

Storage_GetCardEntryAddress::
    push bc
    push de
    ld hl, wDirectoryCards
    ld de, CARD_ENTRY_SIZE_BYTES
    call Storage_AdvanceEntryAddress
    pop de
    pop bc
    ret

Storage_GetSignalEntryAddress::
    push bc
    push de
    ld hl, wDirectorySignals
    ld de, SIGNAL_ENTRY_SIZE_BYTES
    call Storage_AdvanceEntryAddress
    pop de
    pop bc
    ret

Storage_AdvanceEntryAddress:
    and a
    ret z
    ld b, a
.advanceToNextEntry
    add hl, de
    dec b
    jr nz, .advanceToNextEntry
    ret

Storage_ClearCardEntry::
    call Storage_GetCardEntryAddress
    ld a, ENTRY_STATUS_FREE
    ld [hl], a
    ret

Storage_ClearSignalEntry::
    call Storage_GetSignalEntryAddress
    ld a, ENTRY_STATUS_FREE
    ld [hl], a
    ret

Storage_WriteCardEntry:
    call Storage_GetCardEntryAddress
    ld a, ENTRY_STATUS_USED
    ld [hli], a
    ld b, NAME_LENGTH
.copyNameByte
    ld a, [de]
    ld [hli], a
    inc de
    dec b
    jr nz, .copyNameByte
    ret

Storage_WriteSignalEntry:
    call Storage_GetSignalEntryAddress
    ld a, ENTRY_STATUS_USED
    ld [hli], a
    ld a, c
    ld [hli], a
    ld b, NAME_LENGTH
.copyNameByte
    ld a, [de]
    ld [hli], a
    inc de
    dec b
    jr nz, .copyNameByte
    ret

Storage_FindFreeCard::
    ld c, 0
.inspectCard
    ld a, c
    call Storage_GetCardEntryAddress
    ld a, [hl]
    cp ENTRY_STATUS_USED
    jr nz, .freeCardFound
    inc c
    ld a, c
    cp CARD_COUNT_MAX
    jr nz, .inspectCard
    Throw ERROR_CARD_LIST_FULL
.freeCardFound
    ld a, c
    ld [wTargetCard], a
    Succeed

Storage_FindFreeSignalSlot::
    ld c, 0
.inspectSlot
    ld a, [wSignalSlotLimit]
    cp c
    jr z, .noFreeSlot
    ld a, c
    call Storage_GetSignalEntryAddress
    ld a, [hl]
    cp ENTRY_STATUS_USED
    jr nz, .freeSlotFound
    inc c
    jr .inspectSlot
.noFreeSlot
    Throw ERROR_STORAGE_FULL
.freeSlotFound
    ld a, c
    ld [wTargetSlot], a
    Succeed

Storage_CountUsedSignals::
    ld c, 0
    ld d, 0
.inspectSlot
    ld a, c
    call Storage_GetSignalEntryAddress
    ld a, [hl]
    cp ENTRY_STATUS_USED
    jr nz, .nextSlot
    inc d
.nextSlot
    inc c
    ld a, c
    cp SIGNAL_SLOT_COUNT
    jr nz, .inspectSlot
    ld a, d
    ret

Storage_CheckCardHasRoom::
    ld a, [wTargetCard]
    call Storage_RebuildSignalIndex
    ld a, [wCardSignalCount]
    cp SIGNALS_PER_CARD_MAX
    jr c, .cardHasRoom
    Throw ERROR_CARD_FULL
.cardHasRoom
    Succeed

Storage_RebuildCardIndex::
    xor a
    ld [wUsedCardCount], a
    ld c, 0
.inspectCard
    ld a, c
    call Storage_GetCardEntryAddress
    ld a, [hl]
    cp ENTRY_STATUS_USED
    jr nz, .nextCard
    ld a, [wUsedCardCount]
    ld b, a
    inc a
    ld [wUsedCardCount], a
    ld hl, wUsedCardIndexes
    ld a, l
    add b
    ld l, a
    jr nc, .storeCardIndex
    inc h
.storeCardIndex
    ld [hl], c
.nextCard
    inc c
    ld a, c
    cp CARD_COUNT_MAX
    jr nz, .inspectCard
    ret

Storage_RebuildSignalIndex::
    ld e, a
    xor a
    ld [wCardSignalCount], a
    ld c, 0
.inspectSlot
    ld a, c
    call Storage_GetSignalEntryAddress
    ld a, [hli]
    cp ENTRY_STATUS_USED
    jr nz, .nextSlot
    ld a, [hl]
    cp e
    jr nz, .nextSlot
    ld a, [wCardSignalCount]
    cp SIGNALS_PER_CARD_MAX
    jr nc, .nextSlot
    ld b, a
    inc a
    ld [wCardSignalCount], a
    ld hl, wCardSignalIndexes
    ld a, l
    add b
    ld l, a
    jr nc, .storeSlotIndex
    inc h
.storeSlotIndex
    ld [hl], c
.nextSlot
    inc c
    ld a, c
    cp SIGNAL_SLOT_COUNT
    jr nz, .inspectSlot
    ret

Storage_CommitNewCard::
    ld a, [wTargetCard]
    cp CARD_COUNT_MAX
    jr c, .cardIsValid
    Throw ERROR_INVALID_SLOT
.cardIsValid
    ld de, wNameBuffer
    call Storage_WriteCardEntry
    call Storage_FlushDirectory
    and a
    ret z
    push af
    ld a, [wTargetCard]
    call Storage_ClearCardEntry
    pop af
    ret

Storage_CommitNewSignal::
    ld a, [wSignalSlotLimit]
    ld b, a
    ld a, [wTargetSlot]
    cp b
    jr c, .slotIsValid
    Throw ERROR_INVALID_SLOT
.slotIsValid
    ld a, [wTargetCard]
    cp CARD_COUNT_MAX
    jr c, .cardIsValid
    Throw ERROR_INVALID_SLOT
.cardIsValid
    ld c, a
    ld a, [wTargetSlot]
    ld de, wNameBuffer
    call Storage_WriteSignalEntry
    call Storage_FlushDirectory
    and a
    ret z
    push af
    ld a, [wTargetSlot]
    call Storage_ClearSignalEntry
    pop af
    ret

Storage_CommitNewCardWithSignal::
    ld a, [wSignalSlotLimit]
    ld b, a
    ld a, [wTargetSlot]
    cp b
    jr c, .slotIsValid
    Throw ERROR_INVALID_SLOT
.slotIsValid
    ld a, [wTargetCard]
    cp CARD_COUNT_MAX
    jr c, .cardIsValid
    Throw ERROR_INVALID_SLOT
.cardIsValid
    ld de, wPendingCardName
    call Storage_WriteCardEntry
    ld a, [wTargetCard]
    ld c, a
    ld a, [wTargetSlot]
    ld de, wNameBuffer
    call Storage_WriteSignalEntry
    call Storage_FlushDirectory
    and a
    ret z
    push af
    ld a, [wTargetCard]
    call Storage_ClearCardEntry
    ld a, [wTargetSlot]
    call Storage_ClearSignalEntry
    pop af
    ret

Storage_DeleteSignal::
    cp SIGNAL_SLOT_COUNT
    jr c, .slotIsValid
    Throw ERROR_INVALID_SLOT
.slotIsValid
    call Storage_ClearSignalEntry
    jp Storage_FlushDirectory

Storage_DeleteCard::
    cp CARD_COUNT_MAX
    jr c, .cardIsValid
    Throw ERROR_INVALID_SLOT
.cardIsValid
    ld e, a
    ld c, 0
.inspectSignal
    ld a, c
    call Storage_GetSignalEntryAddress
    ld a, [hli]
    cp ENTRY_STATUS_USED
    jr nz, .nextSignal
    ld a, [hl]
    cp e
    jr nz, .nextSignal
    ld a, c
    call Storage_ClearSignalEntry
.nextSignal
    inc c
    ld a, c
    cp SIGNAL_SLOT_COUNT
    jr nz, .inspectSignal
    ld a, e
    call Storage_ClearCardEntry
    jp Storage_FlushDirectory

Storage_ValidateCardName::
    call NameBuffer_CountNonSpace
    and a
    jr nz, .nameHasContent
    Throw ERROR_NAME_EMPTY
.nameHasContent
    jp Storage_CheckCardNameUnused

Storage_ValidateSignalName::
    call NameBuffer_CountNonSpace
    and a
    jr nz, .nameHasContent
    Throw ERROR_NAME_EMPTY
.nameHasContent
    jp Storage_CheckSignalNameUnused

Storage_CheckCardNameUnused::
    ld c, 0
.inspectCard
    ld a, c
    call Storage_GetCardEntryAddress
    ld a, [hli]
    cp ENTRY_STATUS_USED
    jr nz, .nextCard
    ld de, wNameBuffer
    ld b, NAME_LENGTH
    call Memory_CompareBytes
    and a
    jr z, .nameAlreadyUsed
.nextCard
    inc c
    ld a, c
    cp CARD_COUNT_MAX
    jr nz, .inspectCard
    Succeed
.nameAlreadyUsed
    Throw ERROR_NAME_IN_USE

Storage_CheckSignalNameUnused::
    ld c, 0
.inspectSlot
    ld a, c
    call Storage_GetSignalEntryAddress
    ld a, [hli]
    cp ENTRY_STATUS_USED
    jr nz, .nextSlot
    ld a, [hli]
    ld b, a
    ld a, [wTargetCard]
    cp b
    jr nz, .nextSlot
    ld de, wNameBuffer
    ld b, NAME_LENGTH
    call Memory_CompareBytes
    and a
    jr z, .nameAlreadyUsed
.nextSlot
    inc c
    ld a, c
    cp SIGNAL_SLOT_COUNT
    jr nz, .inspectSlot
    Succeed
.nameAlreadyUsed
    Throw ERROR_NAME_IN_USE

Storage_SelectSampleSlot::
    inc a
    ld b, a
    srl a
    ld c, a
    ld a, b
    and SLOTS_PER_BANK - 1
    ld hl, SRAM_BASE_ADDRESS
    jr z, .firstHalfSelected
    ld hl, SRAM_BASE_ADDRESS + SLOT_HALF_SIZE_BYTES
.firstHalfSelected
    call Sram_Enable
    ld a, c
    jp Sram_SelectBank

Storage_SaveSampleFromBuffer::
    ld a, [wTargetSlot]
    call Storage_SelectSampleSlot
    push hl
    ld de, wSampleBuffer
    ld bc, SAMPLE_BUFFER_SIZE_BYTES
    call Memory_CopyBytes
    pop hl
    push hl
    ld de, SLOT_SIGNATURE_OFFSET
    add hl, de
    ld a, SAMPLE_BANK_SIGNATURE
    ld [hl], a
    pop hl
    ld de, wSampleBuffer
    ld bc, SAMPLE_BUFFER_SIZE_BYTES
    call Memory_CompareBlock
    ld b, a
    call Sram_Disable
    ld a, b
    and a
    ret z
    Throw ERROR_STORAGE_VERIFY_FAILED

Storage_LoadSampleToBuffer::
    Try Storage_VerifySampleSignature
    ld a, [wTargetSlot]
    call Storage_SelectSampleSlot
    ld d, h
    ld e, l
    ld hl, wSampleBuffer
    ld bc, SAMPLE_BUFFER_SIZE_BYTES
    call Memory_CopyBytes
    call Sram_Disable
    Succeed

Storage_VerifySampleSignature::
    ld a, [wTargetSlot]
    call Storage_SelectSampleSlot
    ld de, SLOT_SIGNATURE_OFFSET
    add hl, de
    ld a, [hl]
    ld b, a
    call Sram_Disable
    ld a, b
    cp SAMPLE_BANK_SIGNATURE
    jr z, .signatureIntact
    Throw ERROR_SIGNAL_DAMAGED
.signatureIntact
    Succeed
