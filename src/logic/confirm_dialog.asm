INCLUDE "common.inc"

MACRO LoadDialogPointer
    ld a, [\1]
    ld e, a
    ld a, [\1 + 1]
    ld d, a
    or e
ENDM

MACRO PrintOptionalDialogText
    LoadDialogPointer \1
    jr z, .skipText\@
    ld hl, BACKGROUND_MAP_BASE + (\2) * BACKGROUND_MAP_ROW_STRIDE + (\3)
    call Text_PrintString
.skipText\@
ENDM

SECTION "ConfirmDialogState", WRAM0
wDialogQuestion: ds 2
wDialogDetail: ds 2
wDialogWarning: ds 2
wDialogWarningSecond: ds 2
wDialogLegendFirst: ds 2
wDialogLegendSecond: ds 2
wDialogNameSource: ds 1

SECTION "ConfirmDialog", ROM0

ConfirmDialog_Run::
    ld d, h
    ld e, l
    ld hl, wDialogQuestion
    ld bc, DIALOG_DESCRIPTOR_SIZE_BYTES
    call Memory_CopyBytes
    call Screen_Begin
    PrintOptionalDialogText wDialogQuestion, DIALOG_QUESTION_ROW, DIALOG_QUESTION_COLUMN
    PrintOptionalDialogText wDialogWarning, DIALOG_WARNING_ROW, DIALOG_LINE_COLUMN
    PrintOptionalDialogText wDialogWarningSecond, DIALOG_WARNING_SECOND_ROW, DIALOG_LINE_COLUMN
    PrintOptionalDialogText wDialogLegendFirst, LEGEND_FIRST_ROW, LEGEND_COLUMN
    PrintOptionalDialogText wDialogLegendSecond, LEGEND_SECOND_ROW, LEGEND_COLUMN
    ld a, [wDialogNameSource]
    cp NAME_SOURCE_NONE
    jr nz, .printSubjectName
    PrintOptionalDialogText wDialogDetail, DIALOG_DETAIL_ROW, DIALOG_DETAIL_COLUMN
    jr .subjectDone
.printSubjectName
    call ConfirmDialog_PrintSubjectName
.subjectDone
    call Screen_End
    ld a, THEME_ALERT
    call Theme_Apply
.waitForAnswer
    call Lcd_WaitForVBlankStart
    call Joypad_Read
    ld a, [wJoypadPressed]
    bit JOYPAD_BIT_A, a
    jr nz, .answeredYes
    bit JOYPAD_BIT_B, a
    jr z, .waitForAnswer
    Throw ERROR_CANCELLED
.answeredYes
    Succeed

ConfirmDialog_PrintSubjectName:
    ld a, [wDialogNameSource]
    cp NAME_SOURCE_CARD
    jr nz, .signalName
    ld a, [wTargetCard]
    call Storage_GetCardEntryAddress
    ld de, CARD_ENTRY_NAME_OFFSET
    jr .locateName
.signalName
    ld a, [wTargetSlot]
    call Storage_GetSignalEntryAddress
    ld de, SIGNAL_ENTRY_NAME_OFFSET
.locateName
    add hl, de
    ld d, h
    ld e, l
    ld hl, BACKGROUND_MAP_BASE + DIALOG_NAME_ROW * BACKGROUND_MAP_ROW_STRIDE + DIALOG_NAME_COLUMN
    ld b, NAME_LENGTH
    jp Text_PrintGlyphs
