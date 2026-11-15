INCLUDE "common.inc"

SECTION "WorkflowDelete", ROM0

Workflow_DeleteSelectedSignal::
    call SignalListScreen_GetSelectedSlot
    ld [wTargetSlot], a
    ld hl, DialogDeleteSignal
    Try ConfirmDialog_Run
    ld a, [wTargetSlot]
    call Storage_DeleteSignal
    and a
    ret nz
    call Jingle_PlayDeletion
    Succeed
