INCLUDE "common.inc"

SECTION "Strings", ROM0

StringTitleCards::
    db "CARDS", STRING_END
StringEmptyCard::
    db "EMPTY CARD", STRING_END
StringEmptyCardHint::
    db "PRESS START TO ADD", STRING_END
StringUsageLabel::
    db "SIGNALS ", STRING_END
StringUsageSeparator::
    db "/", STRING_END
StringLegendCardsFirst::
    db "A=OPEN", STRING_END
StringLegendListFirst::
    db "A=OK B=BACK", STRING_END
StringLegendListSecond::
    db "START=NEW SELECT=DEL", STRING_END

StringTitleNameSignal::
    db "NAME THE SIGNAL", STRING_END
StringTitleNameCard::
    db "NAME THE CARD", STRING_END
StringLegendNameFirst::
    db "A=PICK B=BACK", STRING_END
StringLegendNameSecond::
    db "START=SAVE", STRING_END

StringAcquireWaiting::
    db "WAITING FOR SIGNAL", STRING_END
StringAcquirePoint::
    db "POINT REMOTE AT GBC", STRING_END
StringAcquirePress::
    db "AND PRESS A KEY", STRING_END
StringLegendAcquire::
    db "B=BACK", STRING_END

StringDeleteQuestion::
    db "DELETE SIGNAL?", STRING_END
StringDeleteWarning::
    db "CANNOT BE UNDONE", STRING_END
StringLegendDelete::
    db "A=YES B=NO", STRING_END

StringDiscardQuestion::
    db "DISCARD SIGNAL?", STRING_END
StringDiscardCardQuestion::
    db "DISCARD CARD?", STRING_END
StringDiscardNothingSaved::
    db "NOTHING IS SAVED", STRING_END
StringDiscardDetail::
    db "NAME IS EMPTY", STRING_END
StringDiscardWarning::
    db "SIGNAL WILL BE LOST", STRING_END
StringLegendDiscardFirst::
    db "A=YES: DISCARD", STRING_END
StringLegendDiscardSecond::
    db "B=NO: KEEP EDITING", STRING_END

StringDeleteCardQuestion::
    db "DELETE CARD?", STRING_END
StringDeleteCardWarningFirst::
    db "THIS ALSO DELETES", STRING_END
StringDeleteCardWarningSecond::
    db "ALL ITS SIGNALS", STRING_END
StringDeleteCardSure::
    db "ARE YOU SURE?", STRING_END
StringDeleteCardLostFirst::
    db "ALL ITS SIGNALS", STRING_END
StringDeleteCardLostSecond::
    db "WILL BE LOST", STRING_END
StringLegendContinue::
    db "A=CONTINUE", STRING_END
StringLegendCancel::
    db "B=CANCEL", STRING_END
StringLegendDeleteYes::
    db "A=YES: DELETE", STRING_END
StringLegendDeleteNo::
    db "B=NO: KEEP IT", STRING_END

StringDiagnosticTitle::
    db "SRAM TEST", STRING_END
StringDiagnosticWrite::
    db "A=WRITE PATTERN", STRING_END
StringDiagnosticCycle::
    db "THEN POWER CYCLE", STRING_END
StringDiagnosticHold::
    db "HOLD SELECT AT BOOT", STRING_END
StringDiagnosticVerify::
    db "START=VERIFY", STRING_END
StringDiagnosticExit::
    db "B=EXIT", STRING_END
StringDiagnosticWarning::
    db "WRITE ERASES SAVES", STRING_END
StringDiagnosticBank::
    db "BANK ", STRING_END
StringDiagnosticOk::
    db "OK", STRING_END
StringDiagnosticBad::
    db "BAD", STRING_END
StringDiagnosticAllOk::
    db "ALL BANKS OK", STRING_END
StringDiagnosticSomeBad::
    db "SOME BANKS BAD", STRING_END

StringProbeBanksPrefix::
    db "SRAM BANKS: ", STRING_END
StringProbeBanksSuffix::
    db "/16", STRING_END
StringProbeKeptYes::
    db "SRAM KEPT: YES", STRING_END
StringProbeKeptNo::
    db "SRAM KEPT: NO", STRING_END

StringErrorPrefix::
    db "ERROR E", STRING_END
StringErrorHint::
    db "SEE TECHNICAL.MD", STRING_END
StringLegendError::
    db "A=OK", STRING_END
