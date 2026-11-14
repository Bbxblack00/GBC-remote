INCLUDE "common.inc"

SECTION "Audio", ROM0

Audio_Enable::
    ld a, NR52_AUDIO_ENABLED
    ldh [rNR52], a
    ld a, NR50_FULL_VOLUME_BOTH_SIDES
    ldh [rNR50], a
    ld a, NR51_PULSE1_BOTH_SIDES
    ldh [rNR51], a
    ret

Audio_PlayNote::
    ld a, NR10_SWEEP_DISABLED
    ldh [rNR10], a
    ld a, NR11_DUTY_HALF
    ldh [rNR11], a
    ld a, NR12_FULL_VOLUME_FAST_DECAY
    ldh [rNR12], a
    ld a, e
    ldh [rNR13], a
    ld a, d
    or NR14_TRIGGER
    ldh [rNR14], a
    ret

Audio_Silence::
    ld a, NR12_DAC_OFF
    ldh [rNR12], a
    ld a, NR52_AUDIO_DISABLED
    ldh [rNR52], a
    ret
