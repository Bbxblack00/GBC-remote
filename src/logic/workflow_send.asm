INCLUDE "common.inc"

SECTION "WorkflowSend", ROM0

Workflow_SendSelectedSignal::
    call ListScreen_GetSelectedSlot
    ld [wTargetSlot], a
    Try Storage_LoadSampleToBuffer
    ld a, THEME_SENDING
    call Theme_Apply
    call Clock_EnterSignalSpeed
    call Infrared_EnableLedControl
    call Infrared_ReplaySamplesFromBuffer
    call Infrared_Disable
    call Clock_EnterNormalSpeed
    ld a, THEME_NORMAL
    call Theme_Apply
    Succeed
