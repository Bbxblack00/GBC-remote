INCLUDE "common.inc"

SECTION "Application", ROM0

Application_Run::
    call Storage_Mount
    call Application_Catch
.mainLoop
    call Storage_RebuildCardIndex
    ld a, [wUsedCardCount]
    and a
    jr nz, .showCardList
    call Workflow_RecordFirstSignal
    jr .handleResult
.showCardList
    call CardListScreen_Run
    cp CARD_LIST_ACTION_OPEN
    jr z, .openCard
    cp CARD_LIST_ACTION_NEW
    jr z, .createCard
    call Workflow_DeleteSelectedCard
    jr .handleResult
.openCard
    call Application_RunCard
    jr .mainLoop
.createCard
    call Workflow_CreateCard
.handleResult
    call Application_Catch
    jr .mainLoop

Application_RunCard:
    call CardListScreen_GetSelectedCard
    ld [wSelectedCard], a
    xor a
    ld [wSignalListCursor], a
.cardLoop
    ld a, [wSelectedCard]
    call Storage_RebuildSignalIndex
    call SignalListScreen_Run
    cp SIGNAL_LIST_ACTION_BACK
    ret z
    cp SIGNAL_LIST_ACTION_SEND
    jr z, .sendSignal
    cp SIGNAL_LIST_ACTION_NEW
    jr z, .newSignal
    call Workflow_DeleteSelectedSignal
    jr .handleResult
.newSignal
    call Workflow_RecordSignalInCard
    jr .handleResult
.sendSignal
    call Workflow_SendSelectedSignal
.handleResult
    call Application_Catch
    jr .cardLoop

Application_Catch::
    ld b, a
    call Error_IsDisplayable
    and a
    ret z
    ld a, b
    jp ErrorScreen_Show
