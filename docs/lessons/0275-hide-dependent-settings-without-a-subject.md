# 0275 — Hide dependent settings without a subject

Date: 2026-08-30

## Symptom

The Tags screen showed a Tag Counter display setting when no saved Tag existed,
so changing it could not affect anything visible.

## Root Cause

The counter preference was rendered unconditionally instead of deriving its
availability from the saved-tag catalog it configures.

## Fix

iOS and macOS now render Tag Counters only when `savedTags` is nonempty. The
empty Saved Tags guidance remains visible, and the stored preference is left
unchanged.

## Prevention Rule

Hide a presentation setting when its subject does not exist, unless the control
is itself required to create, restore, or discover that subject.

## Regression Safeguard

`SettingsTagPresentationTests` checks both platform implementations for the
saved-tag availability guard.

Related decision: [0702 — Hide Tag Counter Settings Without Tags](../decisions/0702-hide-tag-counter-settings-without-tags.md).
