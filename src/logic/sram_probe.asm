INCLUDE "common.inc"

SECTION "SramProbeState", WRAM0
wSramProbeKept:: ds 1
wSramBankCount:: ds 1
wSignalSlotLimit:: ds 1

SECTION "SramProbe", ROM0

SramProbe_Run::
    call Sram_Enable
    call SramProbe_DetectBankCount
    and a
    ld a, SRAM_PROBE_NO
    jr z, .storeKept
    ld a, SRAM_PROBE_YES
.storeKept
    ld [wSramProbeKept], a
    call SramProbe_WriteMarkers
    call SramProbe_DetectBankCount
    and a
    jr nz, .clampBankCount
    ld a, 1
.clampBankCount
    ld b, SRAM_BANK_LIMIT
    call SramProbe_ClampBankCount
    ld [wSramBankCount], a
    call SramProbe_SlotLimitFor
    ld [wSignalSlotLimit], a
    jp Sram_Disable

SramProbe_WriteMarkers::
    ld c, 0
.writeMarker
    ld a, c
    call Sram_SelectBank
    ld a, c
    xor SRAM_PROBE_KEY
    ld [SRAM_PROBE_ADDRESS], a
    inc c
    ld a, c
    cp SRAM_BANK_COUNT_MAX
    jr nz, .writeMarker
    ret

SramProbe_DetectBankCount::
    xor a
    call Sram_SelectBank
    ld a, [SRAM_PROBE_ADDRESS]
    xor SRAM_PROBE_KEY
    cp SRAM_BANK_COUNT_MAX
    jr nc, .markersInconsistent
    ld b, a
    ld a, SRAM_BANK_COUNT_MAX
    sub b
    ld d, a
    dec a
    and d
    jr nz, .markersInconsistent
    ld c, 0
.verifyBank
    ld a, c
    call Sram_SelectBank
    ld a, [SRAM_PROBE_ADDRESS]
    xor SRAM_PROBE_KEY
    ld e, a
    ld a, d
    dec a
    and c
    add b
    cp e
    jr nz, .markersInconsistent
    inc c
    ld a, c
    cp SRAM_BANK_COUNT_MAX
    jr nz, .verifyBank
    ld a, d
    ret
.markersInconsistent
    xor a
    ret

SramProbe_ClampBankCount::
    cp b
    ret c
    ld a, b
    ret

SramProbe_SlotLimitFor::
    add a
    dec a
    cp SIGNAL_SLOT_COUNT
    ret c
    ld a, SIGNAL_SLOT_COUNT
    ret

SramProbe_PrintKept::
    ld de, StringProbeKeptYes
    ld a, [wSramProbeKept]
    cp SRAM_PROBE_YES
    jr z, .printKept
    ld de, StringProbeKeptNo
.printKept
    jp Text_PrintString

SramProbe_PrintBankCount::
    ld de, StringProbeBanksPrefix
    call Text_PrintString
    ld a, [wSramBankCount]
    call Text_PrintDecimalByte
    ld de, StringProbeBanksSuffix
    jp Text_PrintString
