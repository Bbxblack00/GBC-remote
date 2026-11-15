INCLUDE "common.inc"

SECTION "Stack", WRAM0
wStackBottom: ds STACK_SIZE_BYTES
wStackTop:

SECTION "Main", ROM0
Main::
    di
    ld sp, wStackTop
    call Clock_EnterNormalSpeed
    call Lcd_Initialise
    call SramProbe_Run
    call EventLog_Initialise
    call EventLog_RecordBootFacts
    call Joypad_Read
    ld a, [wJoypadHeld]
    bit JOYPAD_BIT_SELECT, a
    call nz, SramDiagnostic_Run
    jp Application_Run
