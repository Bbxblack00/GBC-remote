INCLUDE "common.inc"

SECTION "Sram", ROM0

Sram_Enable::
    ld a, MBC5_RAM_ENABLE_VALUE
    ld [MBC5_RAM_ENABLE_REGISTER], a
    ret

Sram_Disable::
    ld a, MBC5_RAM_DISABLE_VALUE
    ld [MBC5_RAM_ENABLE_REGISTER], a
    ret

Sram_SelectBank::
    ld [MBC5_RAM_BANK_REGISTER], a
    ret
