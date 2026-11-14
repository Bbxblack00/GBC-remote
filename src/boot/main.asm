INCLUDE "common.inc"

SECTION "Stack", WRAM0
wStackBottom: ds STACK_SIZE_BYTES
wStackTop:

SECTION "Main", ROM0
Main::
    di
    ld sp, wStackTop
    call Clock_ApplySelectedSpeed
    call Lcd_Initialise
    jp Application_Run
