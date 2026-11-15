INCLUDE "common.inc"

MACRO DialogDescriptor
    dw \1, \2, \3, \4, \5, \6
    db \7
ENDM

SECTION "Dialogs", ROM0

DialogDeleteSignal::
    DialogDescriptor StringDeleteQuestion, 0, StringDeleteWarning, 0, StringLegendDelete, 0, NAME_SOURCE_SIGNAL

DialogDeleteCardWarning::
    DialogDescriptor StringDeleteCardQuestion, 0, StringDeleteCardWarningFirst, StringDeleteCardWarningSecond, StringLegendContinue, StringLegendCancel, NAME_SOURCE_CARD

DialogDeleteCardConfirm::
    DialogDescriptor StringDeleteCardSure, 0, StringDeleteCardLostFirst, StringDeleteCardLostSecond, StringLegendDeleteYes, StringLegendDeleteNo, NAME_SOURCE_CARD

DialogDiscardCardWithSignal::
    DialogDescriptor StringDiscardCardQuestion, StringDiscardDetail, StringDiscardWarning, 0, StringLegendDiscardFirst, StringLegendDiscardSecond, NAME_SOURCE_NONE

DialogDiscardCard::
    DialogDescriptor StringDiscardCardQuestion, StringDiscardDetail, StringDiscardNothingSaved, 0, StringLegendDiscardFirst, StringLegendDiscardSecond, NAME_SOURCE_NONE

DialogDiscardSignal::
    DialogDescriptor StringDiscardQuestion, StringDiscardDetail, StringDiscardWarning, 0, StringLegendDiscardFirst, StringLegendDiscardSecond, NAME_SOURCE_NONE

DiscardDialogDescriptors::
    dw DialogDiscardCardWithSignal, DialogDiscardCard, DialogDiscardSignal

DirectoryClassNames::
IF DEF(DEBUG_BUILD)
    dw StringDebugValid, StringDebugUnformatted, StringDebugDamaged, StringDebugNotChecked
ENDC

NameEntryTitles::
    dw StringTitleNameCard, StringTitleNameCard, StringTitleNameSignal
