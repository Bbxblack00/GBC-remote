INCLUDE "common.inc"
INCLUDE "test_framework.inc"

SECTION "InfraredTests", ROM0

Test_QuietCaptureIsTooShort::
    ld a, TEST_BLANK_SRAM_BYTE
    call Test_FillSampleBank
    call Infrared_ValidateCapturedActivity
    ExpectEqual ERROR_SIGNAL_TOO_SHORT
    call Sram_Disable
    TestPassed

Test_ActiveCaptureIsAccepted::
    ld a, TEST_BLANK_SRAM_BYTE
    call Test_FillSampleBank
    ld hl, SRAM_BASE_ADDRESS
    ld c, MINIMUM_SIGNAL_TRANSITIONS + 2
    ld b, 0
.writeAlternatingSample
    ld a, b
    and 1
    ld [hli], a
    inc b
    dec c
    jr nz, .writeAlternatingSample
    call Infrared_ValidateCapturedActivity
    ExpectEqual ERROR_NONE
    call Sram_Disable
    TestPassed
