INCLUDE "common.inc"

SECTION "SignalCapture", ROM0

SignalCapture_WaitAndRecord::
    call Clock_EnterSignalSpeed
    call Infrared_EnableSensor
.waitForSignal
    call Joypad_Read
    ld a, [wJoypadPressed]
    bit JOYPAD_BIT_B, a
    jr nz, .recordingCancelled
    call Infrared_IsSignalDetected
    jr z, .waitForSignal
    call Infrared_CaptureSamplesToBuffer
    call Infrared_Disable
    call Clock_EnterNormalSpeed
    call Infrared_ValidateCapturedActivity
    and a
    ret nz
    jp Storage_SaveSampleFromBuffer

.recordingCancelled
    call Infrared_Disable
    call Clock_EnterNormalSpeed
    Throw ERROR_CANCELLED
