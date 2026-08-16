# 0178 — Count Flags when deriving progressive form sections

Date: 2026-08-16

## Symptom

A task's assigned Flags appeared in macOS Task Details but disappeared when
Edit Task opened. The combined Tags and Flags card was available only through
`Add More Details` when the task had no tags.

## Root Cause

The Mac progressive-form visibility predicate treated the shared card as
populated only when tag data existed. Flag state and the defined Flag catalog
were correctly loaded into the form model, but neither participated in the
section-visibility decision.

## Fix

One shared tag-and-Flag content predicate now drives compact and Mac form
section derivation. Assigned Flags, available defined Flags, and a Flag draft
all keep the combined card visible, alongside the existing tag conditions.

## Prevention Rule

When multiple editors share one progressively disclosed section, derive that
section's visibility from every editor's selected values, available catalog,
and draft state. Loading a value into form state is insufficient if the
container can still hide it.

## Regression Safeguard

`TaskFormFlagSuggestionPresentationTests` verifies that assigned and defined
Flags populate the combined section, while `TaskFormMacLayoutRegressionTests`
ensures every Mac progressive-form derivation uses the shared predicate. The
Mac Task Forms Keep Flags Visible scenario records the expected journey.
