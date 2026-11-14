INCLUDE "common.inc"

SECTION "ErrorHandling", ROM0

Error_IsDisplayable::
    cp ERROR_NONE
    jr z, .notDisplayable
    cp ERROR_CANCELLED
    jr z, .notDisplayable
    ld a, ERROR_IS_DISPLAYABLE
    ret
.notDisplayable
    ld a, ERROR_IS_NOT_DISPLAYABLE
    ret
