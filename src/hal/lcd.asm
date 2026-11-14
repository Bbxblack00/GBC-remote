INCLUDE "common.inc"

SECTION "Lcd", ROM0

Lcd_WaitForVBlankStart::
.leaveVBlankStartLine
    ldh a, [rLY]
    cp LCD_VBLANK_FIRST_LINE
    jr z, .leaveVBlankStartLine
.enterVBlankStartLine
    ldh a, [rLY]
    cp LCD_VBLANK_FIRST_LINE
    jr nz, .enterVBlankStartLine
    ret

Lcd_Disable::
    ldh a, [rLCDC]
    and LCDC_LCD_ENABLED
    ret z
    call Lcd_WaitForVBlankStart
    ld a, LCDC_LCD_DISABLED
    ldh [rLCDC], a
    ret

Lcd_Enable::
    ld a, LCDC_LCD_ENABLED | LCDC_BACKGROUND_ENABLED | LCDC_TILE_DATA_AT_8000
    ldh [rLCDC], a
    ret

Lcd_ClearBackgroundMap::
    ld hl, BACKGROUND_MAP_BASE
    ld bc, BACKGROUND_MAP_SIZE_BYTES
    ld a, GLYPH_SPACE
    jp Memory_FillBytes

Lcd_LoadFontTiles:
    ld hl, VRAM_TILE_DATA_BASE
    ld de, FontGlyphRows
    ld bc, FONT_SOURCE_SIZE_BYTES
.expandGlyphRow
    ld a, [de]
    ld [hli], a
    ld a, TILE_PLANE_EMPTY
    ld [hli], a
    inc de
    dec bc
    ld a, b
    or c
    jr nz, .expandGlyphRow
    ret

Lcd_Initialise::
    call Lcd_Disable
    call Lcd_LoadFontTiles
    ld a, VRAM_BANK_ATTRIBUTES
    ldh [rVBK], a
    call Lcd_ClearBackgroundMap
    ld a, VRAM_BANK_TILE_INDICES
    ldh [rVBK], a
    jp Lcd_ClearBackgroundMap
