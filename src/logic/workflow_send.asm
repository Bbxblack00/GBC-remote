INCLUDE "common.inc"

SECTION "WorkflowSend", ROM0

Workflow_SendSelectedSignal::
    call ListScreen_GetSelectedSlot
    ld [wTargetSlot], a
    Try Storage_VerifySampleSignature
    ld a, THEME_SENDING
    call Theme_Apply
    ld a, [wTargetSlot]
    call Storage_SelectSampleBank
    call Infrared_EnableLedControl
    call Infrared_ReplaySamplesFromSram
    call Infrared_Disable
    call Sram_Disable
    ld a, THEME_NORMAL
    call Theme_Apply
    Succeed
