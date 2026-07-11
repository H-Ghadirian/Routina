# 0372: Hide Completed Tasks From Calendar Schedule

Date: 2026-07-11

Status: Accepted

Refines: [0006 Make Planner Timeline Activity Configurable](0006-make-planner-timeline-activity-configurable.md), [0094 Suggest Only Completed Activity in the Planner Calendar](0094-suggest-only-completed-activity-in-planner-calendar.md), [0367 Show Day Agenda Done Sections](0367-show-day-agenda-done-sections.md), [0368 Hide Assumed-Done Calendar Layer by Default](0368-hide-assumed-done-calendar-layer-by-default.md), [0369 Show Day Task List Columns in Planner Calendar](0369-show-day-task-list-columns-in-planner-calendar.md)

## Context

The Planner Calendar `Schedule` view is the editable planning surface. Earlier behavior let recorded completed timeline activity and opt-in assumed-done activity appear as automatic blocks in that timed grid, which helped review what happened but also made finished tasks look scheduled again after the user marked them done.

Users expect `Schedule` to show work that has been intentionally placed or has explicit task scheduling metadata, not ordinary completion history.

## Decision

Calendar `Schedule` renders task-backed blocks only when they are persisted Planner placements, all-day task placements, or exact task schedules derived from task date/time metadata. Marking a task done does not create or keep a completion-derived automatic block in the timed grid, the Needs Time lane, or the all-day lane.

Recorded completions and synthetic assumed-done rows remain available in the day task sidebar and Calendar `List` columns under `Dones` and `Assumed done`. Those review surfaces continue to use timeline activity for day summaries without creating, moving, or deleting Planner blocks.

## Consequences

- Completing a task no longer makes it appear on the editable Calendar `Schedule` unless it was already explicitly placed or exactly scheduled.
- The Schedule view stays focused on intentional planning and exact task schedules.
- Day agenda and Calendar `List` still provide completion review without turning completed work into schedule blocks.
