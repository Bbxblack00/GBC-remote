INCLUDE "common.inc"

SECTION "JingleNotes", ROM0

SuccessJingleNotes::
    dw NOTE_C5
    db NOTE_SHORT_FRAMES
    dw NOTE_E5
    db NOTE_SHORT_FRAMES
    dw NOTE_G5
    db NOTE_SHORT_FRAMES
    dw NOTE_C6
    db NOTE_LONG_FRAMES
    dw JINGLE_NOTE_END

DeletionJingleNotes::
    dw NOTE_G5
    db NOTE_SHORT_FRAMES
    dw NOTE_E5
    db NOTE_SHORT_FRAMES
    dw NOTE_C5
    db NOTE_LONG_FRAMES
    dw JINGLE_NOTE_END
