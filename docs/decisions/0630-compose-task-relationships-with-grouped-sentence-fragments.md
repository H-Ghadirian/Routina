# 0630: Compose Task Relationships With Grouped Sentence Fragments

## Status

Accepted

## Date

2026-08-21

## Refines

- [0188 Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0264 Match Button Hit Areas to Visual Surfaces](0264-match-button-hit-areas-to-visual-surfaces.md)
- [0409 Add Manual Can Complete Task Links](0409-add-manual-can-complete-task-links.md)
- [0512 Present Mac Relationship Suggestions in the Link Task Sheet](0512-present-mac-relationship-suggestions-in-link-task-sheet.md)
- [0624 Hide Empty Linked Tasks by Default](0624-hide-empty-linked-tasks-by-default.md)

## Context

Routina has seven intentional task-relationship types. They include three
directional inverse pairs whose effects are materially different: dependency,
automatic completion, and optional completion. Keeping those meanings available
is useful, but presenting every type as a persistent chip row consumes substantial
space and makes short labels such as `Blocks` and `Blocked by` easy to interpret
from the wrong task's perspective. In manual linking, clicking a task also saved
the selected relationship immediately, before Routina restated its consequence.

User feedback pointed to Jira's scalable relationship picker: a dense vocabulary
can remain available when relationship labels read as sentence fragments from the
current item's perspective and live in a compact menu rather than permanent chips.
Routina additionally needs a consequence preview because its relationships can
change availability or completion state instead of being descriptive only.

## Decision

Routina retains all seven relationship kinds and their storage semantics. The
relationship composer presents them as sentence fragments from the current task's
perspective and groups them in one menu:

- General: `is related to`;
- Dependency: `is blocked by`, `blocks`;
- Automatic Completion: `is done when`, `completes`;
- Optional Completion: `can be completed by`, `can complete`.

The Mac Link Task sheet opens in Search mode, names the current task, and shows the
grouped relationship menu with the existing task search. Selecting a candidate
stages the pair without mutating either task. Routina then explains the direction
and effect using both task names, and `Add Relationship` performs the existing
immediate relationship mutation. Candidate rows do not repeat the globally
selected relationship; they use their secondary line only for meaningful task
status. The same selected kind can seed `Create and Link New Task`.

Search and Suggestions remain explicit modes. Suggestions hides the manual global
relationship menu and search because each proposal owns its own editable grouped
relationship menu, reason, Confirm, and Dismiss controls. Suggestion confirmation
remains the only suggestion path that mutates task data.

When Task Details already has relationships, its Linked Tasks card shows a
relationship count and keeps existing relationships grouped by their
sentence-fragment meaning. On Mac, one `Add` action in the header opens the Link
Task composer, where linking an existing task and creating a new linked task remain
distinct. iOS keeps its platform-appropriate Task Detail add entry point while
shared task forms use the same grouped relationship vocabulary.

## Consequences

- Routina can add relationship types without expanding a permanent chip grid.
- Directional effects are expressed in the context of the two selected tasks.
- Manual linking gains one explicit confirmation step and no longer changes task
  data merely because a candidate row was clicked.
- The Task Details card focuses on existing relationships instead of carrying a
  permanent relationship picker and two creation controls.
- Relationship persistence, inverse-link storage, blocking, automatic fulfillment,
  manual fulfillment, synchronization, and Apple Intelligence availability do not
  change.
