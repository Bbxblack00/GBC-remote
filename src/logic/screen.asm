INCLUDE "common.inc"

SECTION "Screen", ROM0

Screen_Begin::
    call Lcd_Disable
    jp Lcd_ClearBackgroundMap

Screen_End::
    jp Lcd_Enable
