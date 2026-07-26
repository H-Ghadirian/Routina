# 0034 — Drive recurrence editors from the lossless draft

Date: 2026-07-26

## Symptom

The recurrence form exposed Simple and Advanced as separate user choices, and the Advanced yearly editor showed only one month and one date even though structured storage could preserve several. A user could reopen a richer saved schedule without being able to see or recreate its complete selection.

## Root Cause

Visible controls were bound to persistence-specific compatibility state. Each branch implemented only the fields it expected, so the UI's expressive power and collection cardinality could fall behind the authoritative structured model.

## Fix

Add Task and Edit Task now bind one progressive recurrence composer directly to `RoutineRecurrenceDraft` on iOS and macOS. The composer exposes recurrence intent first, progressively reveals fixed schedule details, and binds yearly months and dates to their complete arrays. Compact and structured rules are selected only at the draft resolution boundary.

## Prevention Rule

Recurrence UI must bind to the lossless draft, not directly to a persistence representation or scalar compatibility field. Every stored collection needs a shared editor with matching cardinality on every create and edit surface.

## Regression Safeguard

`RoutineRecurrenceDraftTests` covers compact-to-fixed transitions, lossless simplification, unsupported windows, and several yearly months and dates. The `Unified Recurrence Draft Preserves Existing Models` and `Editing Calendar Routines Preserves All Selected Days` scenarios cover the cross-platform form contract. Decision [0431](../decisions/0431-present-one-progressive-recurrence-composer.md) makes the unified composer durable product behavior.
