INCLUDE "common.inc"
INCLUDE "test_framework.inc"

SECTION "TestRunnerState", WRAM0
wTestResults:: ds MAXIMUM_TEST_COUNT
wTestCount:: ds 1
wTestRunFinished:: ds 1
wTestStackBottom: ds TEST_STACK_SIZE_BYTES
wTestStackTop:

SECTION "TestRunner", ROM0

TestMain::
    di
    ld sp, wTestStackTop
    xor a
    ld [wTestCount], a
    ld [wTestRunFinished], a
    ld hl, wTestResults
    ld bc, MAXIMUM_TEST_COUNT
    ld a, TEST_NOT_RUN
    call Memory_FillBytes
    ld hl, TestTable
    ld de, wTestResults
.runNextTest
    ld a, h
    cp HIGH(TestTableEnd)
    jr nz, .readTestAddress
    ld a, l
    cp LOW(TestTableEnd)
    jr z, .allTestsRun
.readTestAddress
    ld a, [hli]
    ld c, a
    ld a, [hli]
    ld b, a
    push hl
    push de
    ld h, b
    ld l, c
    call Test_CallHl
    pop de
    ld [de], a
    inc de
    ld a, [wTestCount]
    inc a
    ld [wTestCount], a
    pop hl
    jr .runNextTest
.allTestsRun
    ld a, TEST_RUN_FINISHED_MARKER
    ld [wTestRunFinished], a
.idleForever
    halt
    nop
    jr .idleForever

Test_CallHl:
    jp hl

Test_ResetWorld::
    call Storage_FormatMirror
    call Storage_FlushDirectory
    call Storage_RebuildIndex
    jp NameBuffer_Clear

Test_ForgetMirror::
    ld hl, wDirectory
    ld bc, DIRECTORY_SIZE_BYTES
    ld a, TEST_BLANK_SRAM_BYTE
    jp Memory_FillBytes

Test_FillSampleBuffer::
    ld hl, wSampleBuffer
    ld bc, SAMPLE_BUFFER_SIZE_BYTES
    jp Memory_FillBytes
