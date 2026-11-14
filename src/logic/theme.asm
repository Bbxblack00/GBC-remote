INCLUDE "common.inc"

SECTION "Theme", ROM0

Theme_Apply::
    ld l, a
    ld h, 0
    REPT PALETTE_SIZE_SHIFT
        add hl, hl
    ENDR
    ld de, ThemePalettes
    add hl, de
    push hl
    ldh a, [rLCDC]
    and LCDC_LCD_ENABLED
    call nz, Lcd_WaitForVBlankStart
    pop hl
    ld a, BCPS_AUTO_INCREMENT_FROM_FIRST_COLOR
    ldh [rBCPS], a
    ld b, PALETTE_SIZE_BYTES
.writePaletteByte
    ld a, [hli]
    ldh [rBCPD], a
    dec b
    jr nz, .writePaletteByte
    ret
