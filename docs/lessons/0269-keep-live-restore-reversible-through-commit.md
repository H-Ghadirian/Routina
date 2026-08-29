# 0269 — Keep live restore reversible through commit

Date: 2026-08-29

## Symptom

If backup import failed after deleting existing records, the destination store
could be left empty or partially restored even though Settings reported failure.
Discovering an otherwise successful but incomplete restore later also left no
in-app copy of the destination's previous state.

## Root Cause

Import saved the destructive deletion before inserting and saving the replacement,
so `ModelContext.rollback()` could not recover the already committed records.
Restore also had no mandatory verified destination snapshot before mutation.

## Fix

Import now validates the candidate in isolation, creates a verified pre-restore
recovery package, stages deletion and insertion without an intermediate save, and
commits once. CloudKit pull tokens and restored device defaults change only after
that save succeeds. The ten newest verified recovery points remain selectable in
Settings.

## Prevention Rule

Never commit deletion of live user data before its complete replacement is ready.
Validate outside the live store, preserve the destination first, use one persistence
transaction, and postpone irreversible side effects until after the commit.

## Regression Safeguard

`SettingsRoutineDataBackupSafetyTests.failedLiveReplacementRollsBackOriginalData`
proves a malformed package cannot remove the original task.
`restoreCreatesVerifiedRecoveryPointBeforeReplacingLiveData` proves the old data is
captured and restorable, and `recoveryHistoryRetainsTenNewestVerifiedPoints` guards
the bounded recovery history. `recoveryRetentionPreservesThePointCurrentlyBeingRestored`
keeps an older selected source available while creating the new pre-restore point.
