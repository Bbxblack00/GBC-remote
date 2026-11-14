INCLUDE "common.inc"

SECTION "WorkflowDelete", ROM0

Workflow_DeleteSelectedSignal::
    call ListScreen_GetSelectedSlot
    ld [wTargetSlot], a
    Try DeleteDialog_Run
    ld a, [wTargetSlot]
    jp Storage_DeleteSlot
