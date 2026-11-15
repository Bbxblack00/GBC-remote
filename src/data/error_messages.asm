INCLUDE "common.inc"

MACRO ErrorMessage
    dw \1, \2, \3
ENDM

SECTION "ErrorMessages", ROM0

ErrorMessages::
    ErrorMessage 0, 0, 0
    ErrorMessage StringErrorSramWriteFailed, StringErrorDirectoryNotSaved, StringErrorNotSaved
    ErrorMessage 0, 0, 0
    ErrorMessage StringErrorSignalTooShort, StringErrorMoveRemote, StringErrorCloserAndRetry
    ErrorMessage 0, 0, 0
    ErrorMessage 0, 0, 0
    ErrorMessage StringErrorSignalDamaged, StringErrorDeleteItAnd, StringErrorRecordAgain
    ErrorMessage StringErrorCardNotFound, StringErrorRestartProgram, StringErrorProgramWord
    ErrorMessage StringErrorDirectoryDamaged, StringErrorCardsWereLost, 0
    ErrorMessage StringErrorTooManyCards, StringErrorCardLimit, StringErrorDeleteOneFirst
    ErrorMessage StringErrorCardIsFull, StringErrorSignalLimit, StringErrorDeleteOneFirst
    ErrorMessage StringErrorSramWriteFailed, StringErrorSignalNotSaved, StringErrorNotSaved
    ErrorMessage StringErrorSignalNotFound, StringErrorRestartProgram, StringErrorProgramWord
    ErrorMessage 0, 0, 0
