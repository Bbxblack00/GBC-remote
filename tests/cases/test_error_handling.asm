INCLUDE "common.inc"
INCLUDE "test_framework.inc"

SECTION "ErrorHandlingTests", ROM0

ErrorHelper_AlwaysFails:
    Throw ERROR_STORAGE_FULL

ErrorHelper_AlwaysSucceeds:
    Succeed

ErrorHelper_CallsFailingHelper:
    Try ErrorHelper_AlwaysFails
    Throw ERROR_INVALID_SLOT

ErrorHelper_CallsSucceedingHelper:
    Try ErrorHelper_AlwaysSucceeds
    Throw ERROR_INVALID_SLOT

Test_TryPropagatesFailure::
    call ErrorHelper_CallsFailingHelper
    ExpectEqual ERROR_STORAGE_FULL
    TestPassed

Test_TryContinuesAfterSuccess::
    call ErrorHelper_CallsSucceedingHelper
    ExpectEqual ERROR_INVALID_SLOT
    TestPassed

Test_NoneIsNotDisplayable::
    ld a, ERROR_NONE
    call Error_IsDisplayable
    ExpectEqual ERROR_IS_NOT_DISPLAYABLE
    TestPassed

Test_CancelledIsNotDisplayable::
    ld a, ERROR_CANCELLED
    call Error_IsDisplayable
    ExpectEqual ERROR_IS_NOT_DISPLAYABLE
    TestPassed

Test_RealErrorIsDisplayable::
    ld a, ERROR_STORAGE_FULL
    call Error_IsDisplayable
    ExpectEqual ERROR_IS_DISPLAYABLE
    TestPassed
