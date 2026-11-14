INCLUDE "common.inc"

SECTION "EntryPoint", ROM0[ROM_ENTRY_POINT]
    nop
    jp Main
    ds ROM_HEADER_END - @, 0
