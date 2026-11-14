MACRO Try
    call \1
    and a
    ret nz
ENDM

MACRO Throw
    ld a, \1
    ret
ENDM

MACRO Succeed
    ld a, ERROR_NONE
    ret
ENDM
