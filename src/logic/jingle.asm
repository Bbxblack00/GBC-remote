INCLUDE "common.inc"

SECTION "Jingle", ROM0

Jingle_PlaySuccess::
    call Audio_Enable
    ld hl, SuccessJingleNotes
.playNote
    ld a, [hli]
    ld e, a
    ld a, [hli]
    ld d, a
    or e
    jr z, .melodyFinished
    ld a, [hli]
    ld b, a
    push hl
    push bc
    call Audio_PlayNote
    pop bc
.holdNote
    call Lcd_WaitForVBlankStart
    dec b
    jr nz, .holdNote
    pop hl
    jr .playNote
.melodyFinished
    jp Audio_Silence
