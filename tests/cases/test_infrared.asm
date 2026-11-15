INCLUDE "common.inc"
INCLUDE "test_framework.inc"

SECTION "InfraredTests", ROM0

SramTest_WriteAliasedPattern:
    ld d, a
    call Sram_Enable
    ld c, 0
.writeBank
    ld a, c
    call Sram_SelectBank
    ld a, d
    dec a
    and c
    ld b, a
    ld a, SRAM_BANK_COUNT_MAX
    sub d
    add b
    xor SRAM_PROBE_KEY
    ld [SRAM_PROBE_ADDRESS], a
    inc c
    ld a, c
    cp SRAM_BANK_COUNT_MAX
    jr nz, .writeBank
    ret

Test_SramProbeReportsKeptAndFullBankCount::
    call SramProbe_Run
    call SramProbe_Run
    ld a, [wSramProbeKept]
    ExpectEqual SRAM_PROBE_YES
    ld a, [wSramBankCount]
    ExpectEqual SRAM_BANK_COUNT_MAX
    ld a, [wSignalSlotLimit]
    ExpectEqual SIGNAL_SLOT_COUNT
    call Sram_Enable
    ld a, TEST_PROBE_WIPED_BANK
    call Sram_SelectBank
    ld a, TEST_BLANK_SRAM_BYTE
    ld [SRAM_PROBE_ADDRESS], a
    call Sram_Disable
    call SramProbe_Run
    ld a, [wSramProbeKept]
    ExpectEqual SRAM_PROBE_NO
    ld a, [wSramBankCount]
    ExpectEqual SRAM_BANK_COUNT_MAX
    TestPassed

Test_BankCountIsDetectedFromAliasedPatterns::
    ld a, TEST_BANKS_FOUR
    call SramTest_WriteAliasedPattern
    call SramProbe_DetectBankCount
    ExpectEqual TEST_BANKS_FOUR
    ld a, TEST_BANKS_ONE
    call SramTest_WriteAliasedPattern
    call SramProbe_DetectBankCount
    ExpectEqual TEST_BANKS_ONE
    ld a, TEST_BANKS_EIGHT
    call SramTest_WriteAliasedPattern
    call SramProbe_DetectBankCount
    ExpectEqual TEST_BANKS_EIGHT
    ld a, SRAM_BANK_COUNT_MAX
    call SramTest_WriteAliasedPattern
    call SramProbe_DetectBankCount
    ExpectEqual SRAM_BANK_COUNT_MAX
    ld a, TEST_PROBE_WIPED_BANK
    call Sram_SelectBank
    ld a, TEST_BLANK_SRAM_BYTE
    ld [SRAM_PROBE_ADDRESS], a
    call SramProbe_DetectBankCount
    ExpectZero
    call SramProbe_WriteMarkers
    call Sram_Disable
    TestPassed

Test_BankLimitClampsTheDetectedBanks::
    ld a, SRAM_BANK_COUNT_MAX
    ld b, TEST_BANKS_FOUR
    call SramProbe_ClampBankCount
    ExpectEqual TEST_BANKS_FOUR
    ld a, TEST_BANKS_ONE
    ld b, TEST_BANKS_FOUR
    call SramProbe_ClampBankCount
    ExpectEqual TEST_BANKS_ONE
    ld a, TEST_BANKS_EIGHT
    ld b, TEST_BANKS_EIGHT
    call SramProbe_ClampBankCount
    ExpectEqual TEST_BANKS_EIGHT
    TestPassed

Test_SlotLimitFollowsBankCount::
    ld a, TEST_BANKS_ONE
    call SramProbe_SlotLimitFor
    ExpectEqual 1
    ld a, TEST_BANKS_FOUR
    call SramProbe_SlotLimitFor
    ExpectEqual 7
    ld a, TEST_BANKS_EIGHT
    call SramProbe_SlotLimitFor
    ExpectEqual 15
    ld a, SRAM_BANK_COUNT_MAX
    call SramProbe_SlotLimitFor
    ExpectEqual SIGNAL_SLOT_COUNT
    TestPassed

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
