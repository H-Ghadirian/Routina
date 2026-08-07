# 0495: Let Task-List Filters Hide Assumed-Done Rows

Status: Accepted

Date: 2026-08-07

Supersedes: [0410 Show Assumed-Done Home Rows by Default](superseded/0410-show-assumed-done-home-rows-by-default.md)

Refines: [0252 Stabilize Home Task List Presentation Identity](0252-stabilize-home-task-list-presentation-identity.md), [0489 Expand Auto-Assume Done to Scheduled Repeats](0489-expand-auto-assume-done-to-scheduled-repeats.md), [0492 Allow Auto-Assume Done for One-Off Scheduled Blocks](0492-allow-auto-assume-done-for-one-off-scheduled-blocks.md)

## Context

Showing assumed-done rows by default keeps the provisional completion state and
its correction actions discoverable. Some people nevertheless want a quieter
task list after they have reviewed that state. The earlier all-or-nothing rule
did not allow that deliberate preference.

## Decision

Home task lists on iOS and macOS show assumed-done rows by default. Their
filters expose `Hide assumed-done tasks`, which defaults off. Enabling it hides
only displays whose current occurrence is assumed done; clearing filters makes
the rows visible again.

The preference persists in temporary Home view state and each task-list type's
filter snapshot. It is an active filter: summaries, result counts, and compact
active-filter chips identify the hidden state and can clear it directly.

The filter affects only Home task-list membership. It does not change
auto-assume eligibility, completion history, Task Detail, Calendar blocks,
Planner Calendar layers, or synthetic assumed-done activity.

## Consequences

- New and reset task-list filters retain visible assumed-done rows.
- People can deliberately reduce task-list noise without losing the underlying
  assumption or changing other surfaces.
- Shared task-list filtering owns this predicate so iOS and macOS present the
  same rows for the same saved filter state.
