SECTION "Memory", ROM0

Memory_FillBytes::
    ld d, a
.fillByte
    ld a, d
    ld [hli], a
    dec bc
    ld a, b
    or c
    jr nz, .fillByte
    ret

Memory_CopyBytes::
.copyByte
    ld a, [de]
    ld [hli], a
    inc de
    dec bc
    ld a, b
    or c
    jr nz, .copyByte
    ret

Memory_CompareBlock::
.compareBlockByte
    ld a, [de]
    sub [hl]
    ret nz
    inc hl
    inc de
    dec bc
    ld a, b
    or c
    jr nz, .compareBlockByte
    xor a
    ret

Memory_CompareBytes::
.compareByte
    ld a, [de]
    sub [hl]
    ret nz
    inc hl
    inc de
    dec b
    jr nz, .compareByte
    xor a
    ret
