INCLUDE "common.inc"

SECTION "Strings", ROM0

StringTitleList::
    db "SIGNALS", STRING_END
StringLegendListFirst::
    db "A=OK B=BACK", STRING_END
StringLegendListSecond::
    db "START=NEW SELECT=DEL", STRING_END

StringTitleName::
    db "NAME THE SIGNAL", STRING_END
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
StringDiscardDetail::
    db "NAME IS EMPTY", STRING_END
StringDiscardWarning::
    db "SIGNAL WILL BE LOST", STRING_END
StringLegendDiscardFirst::
    db "A=YES: DISCARD", STRING_END
StringLegendDiscardSecond::
    db "B=NO: KEEP EDITING", STRING_END

StringErrorPrefix::
    db "ERROR E", STRING_END
StringErrorHint::
    db "SEE README TABLE", STRING_END
StringLegendError::
    db "A=OK", STRING_END
