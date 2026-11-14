INCLUDE "common.inc"

MACRO PadCaptureSampleToReplayCadence
    nop
ENDM

MACRO PadReplayByteToCaptureCadence
    nop
ENDM

MACRO CaptureSampleBit
    ldh a, [c]
.afterRead\1
    rra
    rra
    rr b
    PadCaptureSampleToReplayCadence
ENDM

MACRO ReplaySampleBit
    rr b
    ld a, RP_READ_DISABLED_LED_OFF
    rla
.beforeWrite\1
    ldh [c], a
ENDM

SECTION "Infrared", ROM0

Infrared_EnableSensor::
    ld a, RP_READ_ENABLED
    ldh [rRP], a
    ret

Infrared_EnableLedControl::
    ld a, RP_READ_DISABLED_LED_OFF
    ldh [rRP], a
    ret

Infrared_Disable::
    ld a, RP_READ_DISABLED_LED_OFF
    ldh [rRP], a
    ret

Infrared_IsSignalDetected::
    ldh a, [rRP]
    cpl
    and RP_SENSOR_DATA_BIT_MASK
    ret

Infrared_CaptureSamplesToSram::
    ld hl, SRAM_BASE_ADDRESS
    ld c, LOW(rRP)
    ld e, SAMPLE_REGION_END_HIGH_BYTE
.captureByte
    FOR bitIndex, SAMPLES_PER_BYTE
        CaptureSampleBit {d:bitIndex}
    ENDR
    ld a, b
    cpl
    ld [hli], a
    ld a, h
    cp e
    jr nz, .captureByte
    ret

Infrared_ReplaySamplesFromSram::
    ld hl, SRAM_BASE_ADDRESS
    ld c, LOW(rRP)
    ld e, SAMPLE_REGION_END_HIGH_BYTE
.replayByte
    ld a, [hli]
    ld b, a
    PadReplayByteToCaptureCadence
    FOR bitIndex, SAMPLES_PER_BYTE
        ReplaySampleBit {d:bitIndex}
    ENDR
    ld a, h
    cp e
    jr nz, .replayByte
    ret

Infrared_ValidateCapturedActivity::
    ld hl, SRAM_BASE_ADDRESS
    ld a, [hli]
    ld d, a
    ld c, 0
.inspectByte
    ld a, [hli]
    cp d
    jr z, .byteUnchanged
    ld d, a
    inc c
    ld a, c
    cp MINIMUM_SIGNAL_TRANSITIONS
    jr z, .activityConfirmed
.byteUnchanged
    ld a, h
    cp SAMPLE_REGION_END_HIGH_BYTE
    jr nz, .inspectByte
    Throw ERROR_SIGNAL_TOO_SHORT
.activityConfirmed
    Succeed
