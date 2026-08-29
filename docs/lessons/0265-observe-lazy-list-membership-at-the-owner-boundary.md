# 0265 — Observe lazy-list membership at the owner boundary

Date: 2026-08-29

## Symptom

Mac Task Ladder continued to show `Buy airpods` and count it after its details
showed an unresolved `Blocked by` relationship to a prerequisite that was paused
without ever completing.

## Root Cause

The reducer's cached presentation correctly excluded the relationship-blocked
task, but the Mac view still read presentation membership and counts inside
descendant builders below `HSplitView` and `LazyVStack`. Those retained builders
could continue presenting the previous row set while Task Details observed newer
relationship state.

## Fix

The Task Ladder workspace now observes presentation, search presentation, search
membership, and selection at its owning `body` boundary and passes those immutable
values into the controls and lazy list. Rows, section counts, and the toolbar item
count therefore consume the same replacement snapshot without changing the scroll
container's identity. The relationship regression also covers a paused prerequisite
with no completion in either stored relationship direction.

## Prevention Rule

State that controls lazy-list membership or counts must be observed before the
owner constructs a split view or lazy container and passed down as immutable input.
Do not rely on store reads inside retained descendant builders, and do not reset a
scrolling container's identity to force ordinary data updates.

## Regression Safeguard

`TaskRankingPresentationTests.pausedPrerequisiteWithoutACompletionKeepsItsDependentOutOfTheLadder`
protects the exact blocking semantics.
`taskLadderObservesReplacementPresentationsBeforeBuildingTheSplitView` guards the
Mac observation boundary, and the Mac Task Ladder relationship scenario requires
visible row membership and counts to change together.
