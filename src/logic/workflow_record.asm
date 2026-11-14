INCLUDE "common.inc"

SECTION "WorkflowRecord", ROM0

Workflow_RecordNewSignal::
    Try Storage_FindFreeSlot
    call AcquireScreen_Show
    Try SignalCapture_WaitAndRecord
    Try NameEntryScreen_Run
    Try Storage_CommitNewSignal
    call Jingle_PlaySuccess
    Succeed
