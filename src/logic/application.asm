INCLUDE "common.inc"

SECTION "Application", ROM0

Application_Run::
    call Storage_Mount
    call Application_Catch
.mainLoop
    call Storage_RebuildIndex
    ld a, [wUsedSlotCount]
    and a
    jr nz, .showList
    call Workflow_RecordNewSignal
    jr .handleResult
.showList
    call ListScreen_Run
    cp LIST_ACTION_NEW
    jr z, .startNewRecording
    cp LIST_ACTION_SEND
    jr z, .sendSignal
    call Workflow_DeleteSelectedSignal
    jr .handleResult
.startNewRecording
    call Workflow_RecordNewSignal
    jr .handleResult
.sendSignal
    call Workflow_SendSelectedSignal
.handleResult
    call Application_Catch
    jr .mainLoop

Application_Catch::
    ld b, a
    call Error_IsDisplayable
    and a
    ret z
    ld a, b
    jp ErrorScreen_Show
