INCLUDE "common.inc"
INCLUDE "test_framework.inc"

SECTION "InfraredTests", ROM0

Test_QuietCaptureIsTooShort::
    ld a, TEST_BLANK_SRAM_BYTE
    call Test_FillSampleBuffer
    call Infrared_ValidateCapturedActivity
    ExpectEqual ERROR_SIGNAL_TOO_SHORT
    TestPassed

Test_ActiveCaptureIsAccepted::
    ld a, TEST_BLANK_SRAM_BYTE
    call Test_FillSampleBuffer
    ld hl, wSampleBuffer
    ld c, MINIMUM_SIGNAL_TRANSITIONS + 2
    ld b, 0
.writeAlternatingByte
    ld a, b
    and 1
    ld [hli], a
    inc b
    dec c
    jr nz, .writeAlternatingByte
    call Infrared_ValidateCapturedActivity
    ExpectEqual ERROR_NONE
    TestPassed
