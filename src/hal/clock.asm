INCLUDE "common.inc"

SECTION "Clock", ROM0

Clock_EnterNormalSpeed::
    ldh a, [rKEY1]
    and KEY1_DOUBLE_SPEED_ACTIVE
    ret z
    jr Clock_ToggleSpeed

Clock_EnterSignalSpeed::
IF SELECTED_CPU_SPEED == CPU_SPEED_DOUBLE
    ldh a, [rKEY1]
    and KEY1_DOUBLE_SPEED_ACTIVE
    ret nz
    jr Clock_ToggleSpeed
ELSE
    jr Clock_EnterNormalSpeed
ENDC

Clock_ToggleSpeed::
    di
    ld a, JOYPAD_DESELECT_ALL
    ldh [rJOYP], a
    ld a, INTERRUPTS_ALL_DISABLED
    ldh [rIF], a
    ldh [rIE], a
    ld a, KEY1_PREPARE_SPEED_SWITCH
    ldh [rKEY1], a
    stop
    ret
