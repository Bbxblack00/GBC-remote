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
    RegisterTest Test_MountDetectsCorruptedDirectory
    RegisterTest Test_MountRepairsEmptyCorruptedDirectorySilently
    RegisterTest Test_MountRestoresDamagedPrimaryFromBackup
    RegisterTest Test_CardPersistsAcrossReboot
    RegisterTest Test_SignalPersistsAcrossReboot
    RegisterTest Test_CardNameMustBeUnique
    RegisterTest Test_SignalNameIsUniqueWithinCardOnly
    RegisterTest Test_CardListFillsUpAtThirtyTwo
    RegisterTest Test_CardAcceptsEightSignalsAndRejectsNinth
    RegisterTest Test_SignalPoolRunsOutAtThirty
    RegisterTest Test_DeleteSignalFreesSlot
    RegisterTest Test_DeleteCardRemovesItsSignals
    RegisterTest Test_InvalidIndicesAreRejected
    RegisterTest Test_UsedSignalsAreCounted
    RegisterTest Test_CardIndexListsUsedCardsInOrder
    RegisterTest Test_CommitCardWithSignalStoresBoth
    RegisterTest Test_SampleSlotsDoNotOverlap
    RegisterTest Test_SampleSignatureIsPerSlot
    RegisterTest Test_SampleRoundTripsThroughSram

    RegisterTest Test_SramProbeReportsKeptAndFullBankCount
    RegisterTest Test_BankCountIsDetectedFromAliasedPatterns
    RegisterTest Test_BankLimitClampsTheDetectedBanks
    RegisterTest Test_SlotLimitFollowsBankCount
    RegisterTest Test_QuietCaptureIsTooShort
    RegisterTest Test_ActiveCaptureIsAccepted

    RegisterTest Test_LogInitialisationCountsBoots
    RegisterTest Test_LogAppendStoresTheEntry
    RegisterTest Test_LogWrapsAroundAndKeepsTheNewest
    RegisterTest Test_LogRecordsTheMountClasses
    RegisterTest Test_LogRegionDoesNotOverlapTheDirectory

    RegisterTest Test_DecimalWordPrintsFiveDigits
    RegisterTest Test_DecimalWordHandlesTheLimits
    RegisterTest Test_DirectoryBytesInUseCountsEntries

TestTableEnd::
