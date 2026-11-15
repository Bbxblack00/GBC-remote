INCLUDE "common.inc"

SECTION "WorkflowRecord", ROM0

Workflow_RecordFirstSignal::
    Try Storage_FindFreeCard
    Try Storage_FindFreeSignalSlot
    call AcquireScreen_Show
    Try SignalCapture_WaitAndRecord
    ld a, NAME_KIND_CARD_WITH_SIGNAL
    Try NameEntryScreen_Run
    ld hl, wPendingCardName
    ld de, wNameBuffer
    ld bc, NAME_LENGTH
    call Memory_CopyBytes
    ld a, NAME_KIND_SIGNAL
    Try NameEntryScreen_Run
    Try Storage_CommitNewCardWithSignal
    LogEvent EVENT_SAVE, SAVE_CARD_AND_SIGNAL
    call Jingle_PlaySuccess
    Succeed

Workflow_RecordSignalInCard::
    ld a, [wSelectedCard]
    ld [wTargetCard], a
    Try Storage_CheckCardHasRoom
    Try Storage_FindFreeSignalSlot
    call AcquireScreen_Show
    Try SignalCapture_WaitAndRecord
    ld a, NAME_KIND_SIGNAL
    Try NameEntryScreen_Run
    Try Storage_CommitNewSignal
    LogEvent EVENT_SAVE, SAVE_SIGNAL
    call Jingle_PlaySuccess
    Succeed
