INCLUDE "common.inc"

SECTION "SignalCapture", ROM0

SignalCapture_WaitAndRecord::
    call Infrared_EnableSensor
.waitForSignal
    call Joypad_Read
    ld a, [wJoypadPressed]
    bit JOYPAD_BIT_B, a
    jr nz, .recordingCancelled
    call Infrared_IsSignalDetected
    jr z, .waitForSignal

    ld a, [wTargetSlot]
    call Storage_SelectSampleBank
    call Infrared_CaptureSamplesToSram
    call Infrared_Disable
    call Infrared_ValidateCapturedActivity
    ld b, a
    and a
    jr nz, .closeStorage
    ld a, SAMPLE_BANK_SIGNATURE
    ld [SAMPLE_SIGNATURE_ADDRESS], a
.closeStorage
    call Sram_Disable
    ld a, b
    ret

.recordingCancelled
    call Infrared_Disable
    Throw ERROR_CANCELLED
