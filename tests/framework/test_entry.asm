INCLUDE "common.inc"

SECTION "TestEntryPoint", ROM0[ROM_ENTRY_POINT]
    nop
    jp TestMain
    ds ROM_HEADER_END - @, 0
