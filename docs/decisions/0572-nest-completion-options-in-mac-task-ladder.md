# 0572: Nest Completion Options in the Mac Task Ladder

## Status

Superseded by [0574: Separate Task Ladder Placement From Completion](0574-separate-task-ladder-placement-from-completion.md)

## Date

2026-08-15

## Refines

- [0409: Add Manual Can Complete Task Links](0409-add-manual-can-complete-task-links.md)
- [0561: Add a Separate Mac Task-Ranking Ladder](0561-add-separate-mac-task-ranking-ladder.md)
- [0571: Show Task Identity Metadata in the Mac Task Ladder](0571-show-task-identity-metadata-in-mac-task-ladder.md)

## Context

One recurring intention can have several interchangeable ways to satisfy it.
For example, `Exercise` should participate once in the general ranking decision,
while `Walk`, `Gym`, `Swim`, `Running`, and `Hiking` should be compared only
after the person chooses to exercise. Treating every option as a root task makes
the general ladder compare implementation choices with unrelated commitments.

Legacy `Can complete` links are deliberately conditional and may connect two
otherwise standalone tasks. Reinterpreting every such link as ownership would
unexpectedly remove existing source tasks from the root ladder.

## Decision

Task relationships add a distinct inverse pair: `Has completion option` on the
parent intention and `Option for` on the child. The relationship continues to
use manual linked fulfillment: completing an option from Task Detail asks
whether it should also satisfy its parent routine.

The root Mac Task Ladder shows an eligible parent once and suppresses tasks that
are completion options from that root presentation. A parent row reports its
number of currently actionable options and opens a nested ladder containing
only those options. Nested ladders use the existing metric sections,
eligibility rules, direction controls, cached presentation, and Task Detail.
They retain a visible path back to the root and may drill into another explicit
completion-option relationship without revisiting an ancestor.

Categorical values remain task metadata. Moving an option across value sections
therefore changes that option's selected metric exactly as it does at the root.
Manual tie-break ranks are scoped to the parent ladder, so ordering an option
under one parent does not reorder it under another parent or at the root.

Existing `Can complete` / `Can be completed by`, `Completes` / `Done when`,
dependency, and `Related` relationships do not affect Task Ladder nesting.
Home, Backlog, Planner, Timeline, Stats, search, and notifications retain their
existing task visibility.

## Consequences

- A broad intention such as Exercise can retain its own general Importance and
  Urgency while its concrete options keep independent durations and rankings.
- Existing relationship catalogs do not silently change meaning or visibility.
- Completing an option can update both its own history and the parent routine's
  fulfilled history through the existing explicit confirmation.
- The relationship and scope-specific rank keys use existing synced task
  storage, backup, and restore paths without adding a SwiftData entity.
- Blocked, paused, completed, canceled, archived, and Flag-hidden options remain
  absent from the actionable nested ladder just as they are at the root.

## Future Product Exploration

The broader Area, temporary-focus, and `What should I do now?` concepts discussed
alongside this change are intentionally not accepted by this record. Their
refined examples, UI principles, business consequences, decision scenarios, and
open questions are preserved in
[Contextual Task Ladder Product Exploration](../task-ladder-contextual-priority.md)
for a later numbered decision.
