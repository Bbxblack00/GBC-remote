INCLUDE "common.inc"

SECTION "WorkflowCard", ROM0

Workflow_CreateCard::
    Try Storage_FindFreeCard
    ld a, NAME_KIND_CARD
    Try NameEntryScreen_Run
    Try Storage_CommitNewCard
    Succeed

Workflow_DeleteSelectedCard::
    call CardListScreen_GetSelectedCard
    ld [wTargetCard], a
    ld hl, DialogDeleteCardWarning
    Try ConfirmDialog_Run
    ld hl, DialogDeleteCardConfirm
    Try ConfirmDialog_Run
    ld a, [wTargetCard]
    call Storage_DeleteCard
    and a
    ret nz
    call Jingle_PlayDeletion
    Succeed
