DEF TEST_PASSED              EQU 0
DEF TEST_NOT_RUN             EQU $FF
DEF TEST_RUN_FINISHED_MARKER EQU $A5
DEF MAXIMUM_TEST_COUNT       EQU 64
DEF TEST_STACK_SIZE_BYTES    EQU 128

DEF TEST_BLANK_SRAM_BYTE      EQU $00

DEF assertionNumber = 0

MACRO ExpectEqual
    cp \1
    jr z, .assertionPassed\@
    DEF assertionNumber += 1
    ld a, assertionNumber
    ret
.assertionPassed\@
ENDM

MACRO ExpectZero
    ExpectEqual 0
ENDM

MACRO TestPassed
    ld a, TEST_PASSED
    ret
ENDM

MACRO RegisterTest
TestEntry_\1:
    dw \1
ENDM
