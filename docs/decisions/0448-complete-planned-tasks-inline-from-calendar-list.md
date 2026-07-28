# 0448: Complete Planned Tasks Inline From Calendar List

Date: 2026-07-28

Status: Accepted

Refines: [0036 Treat Completion Times as Planner Finish Times](0036-treat-completion-times-as-planner-finish-times.md), [0369 Show Day Task List Columns in Planner Calendar](0369-show-day-task-list-columns-in-planner-calendar.md), [0370 Confirm Assumed-Done Rows Inline](0370-confirm-assumed-done-rows-inline.md), [0435 Edit Calendar List Done Times From Mac Task Detail](0435-edit-calendar-list-done-times-from-mac-task-detail.md)

## Context

Planner Calendar `List` began as a read-only comparison surface, with one narrow exception for resolving synthetic assumed-done rows. That separation protects Planner blocks from accidental edits, but it also forces users to leave the list to record that a visible planned task was completed.

Completion is outcome evidence rather than a change to the planned block. The list can therefore support a focused completion action without becoming a general Planner editing surface.

## Decision

On macOS, hovering an eligible `Planned tasks` row in Planner Calendar `List` shows a green completion button. Pressing it completes the represented task occurrence through the shared routine completion history path and immediately moves the visible row to `Dones` after persistence succeeds.

The row is eligible only when the selected calendar day is today or in the past and the action can resolve the complete task in one step. Sequential-step tasks and checklist-completion tasks continue to use Task Detail so the green button cannot misleadingly represent partial progress as Done. Exact timed routines use the selected scheduled occurrence and retain duplicate/missed/canceled resolution safeguards.

Completion timestamps follow the represented occurrence:

- today uses the actual completion time;
- a historical timed Planner row uses the planned block finish;
- a historical untimed row uses its recurrence time when available, otherwise noon;
- an exact timed routine uses its scheduled occurrence timestamp.

This action does not create, move, resize, or delete a `DayPlanBlock`. Calendar `List` columns still do not provide drag payloads or general block editing. The right-side day task sidebar keeps its existing planned-row behavior; this planned completion affordance is scoped to Calendar `List`.

Recorded Done-row time correction remains in the Task Detail companion pane.

## Consequences

- Users can complete a planned task directly where they compare day agendas.
- Planner placement remains separate from completion evidence.
- Future occurrences and tasks requiring partial-progress UI do not expose a misleading one-click Done action.
- The lightweight day-task overlay keeps the successful row transition immediate without fetching or regrouping history from the scrolling render path.
