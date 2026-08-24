# 0238 — Derive field actions and affordances from their own state

Date: 2026-08-24

## Symptom

Task Details could lose its `Estimate` add action after Focus was enabled or
Story points were recorded, even though no duration estimate existed. During
active Focus, Effort and Focus headers still showed a clickable disclosure
chevron although their forced-open content could not collapse.

## Root Cause

Estimate eligibility was derived from an aggregate Estimation section instead
of the missing Estimate field itself. Forced expansion changed content behavior
without changing the header's button and icon presentation. In both cases, one
control's visible affordance was coupled to unrelated or incomplete state.

## Fix

A shared eligibility rule now derives the Estimate action only from
`estimatedDurationMinutes`, and both platforms use it. Forced-open Effort and
Focus headers render as static labels without a chevron; their disclosure
button returns only when collapse is available again.

## Prevention Rule

Derive a field-specific add action from that field's own missing state. Derive
an affordance from the action currently available: if content is forced open,
do not render clickable disclosure chrome.

## Regression Safeguard

`TaskDetailSharedViewSupportTests` covers the Estimate eligibility matrix,
cross-platform chooser wiring, and forced-header structure.
`TaskDetailTimeSpentPresentationTests` verifies that active Focus forces Effort
open while suppressing disclosure.

See [Decision 0652](../decisions/0652-keep-effort-fields-independent-and-disclosures-honest.md)
and [Regression Scenarios](../scenarios/README.md#task-effort-fields-stay-independent-and-disclosures-stay-honest).
