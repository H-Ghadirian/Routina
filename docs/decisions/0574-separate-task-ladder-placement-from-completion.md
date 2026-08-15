# 0574: Separate Task Ladder Placement From Completion

## Status

Accepted

## Date

2026-08-15

## Supersedes

- [0572: Nest Completion Options in the Mac Task Ladder](0572-nest-completion-options-in-mac-task-ladder.md)

## Refines

- [0409: Add Manual Can Complete Task Links](0409-add-manual-can-complete-task-links.md)
- [0561: Add a Separate Mac Task-Ranking Ladder](0561-add-separate-mac-task-ranking-ladder.md)
- [0571: Show Task Identity Metadata in the Mac Task Ladder](0571-show-task-identity-metadata-in-mac-task-ladder.md)

## Context

Decision 0572 used a dedicated completion-option relationship for both Task
Ladder placement and manual parent fulfillment. That made `Has completion
option` appear beside `Can be completed by`, even though both could produce the
same completion prompt. It also could not represent a Company container whose
tasks should be compared locally without ever completing Company.

Placement and completion answer different questions:

1. Where should this task be compared?
2. What, if anything, should completing it do to another task?

The implementation from 0572 was still development-only and had no user data,
so compatibility migration would add code and ambiguity without preserving any
real records.

## Decision

Mac Task Ladder organization stores one optional parent placement per task,
independently of task relationships. A parent may be either:

- a normal task, such as Exercise; or
- a container-only Task Ladder group, such as Company.

Groups are not fake tasks. They have a name, emoji, Ladder metric values, root
tie-break ranks, creation date, and child placements, but no task schedule,
completion action, reminder, history, streak, Home placement, Stats contribution,
or task-limit effect. Groups remain root containers in this version. Tasks may
nest under a group or another task, and cycles are rejected.

The Task Ladder toolbar creates and edits groups. A task row's `Organize in Task
Ladder…` action opens a searchable placement editor containing the general
ladder, groups, and valid task parents. Choosing a normal task parent separately
offers three completion behaviors:

- `Does not complete parent` stores no completion relationship for that pair;
- `Can complete parent — ask me` uses the existing manual `Can complete`
  relationship;
- `Completes parent automatically` uses the existing automatic `Completes`
  relationship.

Choosing a container-only group presents no completion control. Placement never
infers a completion rule, and a standalone `Can complete` or `Completes`
relationship never infers placement.

Placed actionable tasks are suppressed from the root and appear in their
parent's cached nested ladder. If a task parent is unavailable, its actionable
children return to the root rather than becoming unreachable. Deleting a group
removes its placements and returns its tasks to the root; it never deletes task
data or history.

The organization is stored as a sanitized, Codable synchronized preference and
included in routine-data backup/import. Scope-specific task ranks continue to
use task ranking storage; group values and root ranks live with the group record.
The scrolling view continues consuming one immutable presentation snapshot.

The unshipped `Has completion option` / `Option for` relationship kinds are
removed without migration.

## Consequences

- Exercise can contain Walk, Gym, and Swim while each child independently uses
  no fulfillment, confirmation-based fulfillment, or automatic fulfillment.
- Company can contain many independent obligations without being completable.
- `Can complete` keeps its existing wording and manual semantics while remaining
  useful between otherwise standalone tasks.
- A parent task can be opened through its nested ladder while Task Details
  remains explicitly available from the row context menu.
- Group deletion is recoverable organization loss rather than task deletion.
- Mac is the first management surface. Other platforms retain the same task and
  fulfillment meanings but do not yet create or navigate Ladder groups.
