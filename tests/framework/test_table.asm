INCLUDE "common.inc"
INCLUDE "test_framework.inc"

SECTION "TestTable", ROM0

TestTable::
    RegisterTest Test_TryPropagatesFailure
    RegisterTest Test_TryContinuesAfterSuccess
    RegisterTest Test_NoneIsNotDisplayable
    RegisterTest Test_CancelledIsNotDisplayable
    RegisterTest Test_RealErrorIsDisplayable

    RegisterTest Test_ClearEmptiesBuffer
    RegisterTest Test_AppendStoresGlyphsInOrder
    RegisterTest Test_AppendIgnoresOverflow
    RegisterTest Test_RemoveLastShortensName
    RegisterTest Test_RemoveLastOnEmptyIsHarmless
    RegisterTest Test_CountNonSpaceIgnoresSpaces

    RegisterTest Test_KeyboardRightWrapsToStart
    RegisterTest Test_KeyboardLeftWrapsToEnd
    RegisterTest Test_KeyboardDownKeepsColumn
    RegisterTest Test_KeyboardUpKeepsColumn
    RegisterTest Test_KeyboardGlyphLookup

    RegisterTest Test_MountFormatsBlankStorage
    RegisterTest Test_CommitPersistsAcrossReboot
    RegisterTest Test_DuplicateNameIsRejected
    RegisterTest Test_BlankNameIsRejected
    RegisterTest Test_FullStorageIsReported
    RegisterTest Test_FindFreeSlotPicksLowestFree
    RegisterTest Test_DeleteFreesSlotAndName
    RegisterTest Test_DeletePersistsAcrossReboot
    RegisterTest Test_InvalidSlotIsRejected
    RegisterTest Test_IndexListsUsedSlotsInOrder
    RegisterTest Test_SampleSignatureDetectsDamage

    RegisterTest Test_QuietCaptureIsTooShort
    RegisterTest Test_ActiveCaptureIsAccepted

TestTableEnd::
