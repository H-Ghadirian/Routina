# 0169 — Verify selection summaries at the return surface

Date: 2026-08-16

## Symptom

The redesigned iOS Filter tags picker showed every active tag clearly, but the
parent Filters row still truncated the selection to the first tag and a count.
After closing the picker, a person could not verify all tags they had selected.

## Root Cause

The picker interaction and the parent summary were treated as separate UI
changes. The picker adopted the complete one-list presentation while the
return surface retained its earlier compact-summary rule and the shared row's
single-line limit.

## Fix

The tag summary now enumerates all selected names, and the shared filter entry
offers an opt-in multiline value used only by Filter tags. Other filter rows
keep their single-line default.

## Prevention Rule

When changing a selection journey, verify both the selection surface and the
surface a person returns to. If the return surface is expected to confirm the
selection, its summary must preserve every required value rather than assuming
the picker alone provides enough visibility.

## Regression Safeguard

`TaskFormIOSLayoutRegressionTests.filterTagEntryWrapsAndNamesEverySelectedTag`
guards the complete tag list, the absence of remainder-count formatting, and
the tag-only multiline opt-in. The iOS Filter Tags regression scenario covers
the return-surface expectation.
