MACRO PrintTextAt
    ld hl, BACKGROUND_MAP_BASE + (\1) * BACKGROUND_MAP_ROW_STRIDE + (\2)
    ld de, \3
    call Text_PrintString
ENDM
