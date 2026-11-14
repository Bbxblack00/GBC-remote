INCLUDE "common.inc"

SECTION "AcquireScreen", ROM0

AcquireScreen_Show::
    call Screen_Begin
    PrintTextAt ACQUIRE_FIRST_ROW, ACQUIRE_COLUMN, StringAcquireWaiting
    PrintTextAt ACQUIRE_FIRST_ROW + ACQUIRE_ROW_STEP, ACQUIRE_COLUMN, StringAcquirePoint
    PrintTextAt ACQUIRE_FIRST_ROW + 2 * ACQUIRE_ROW_STEP, ACQUIRE_COLUMN, StringAcquirePress
    PrintTextAt LEGEND_FIRST_ROW, LEGEND_COLUMN, StringLegendAcquire
    call Screen_End
    ld a, THEME_ACQUIRE
    jp Theme_Apply
