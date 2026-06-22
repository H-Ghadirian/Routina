# Planner Current Behavior

This page summarizes active Planner, timeline activity, focus, Away, and Sleep behavior.

## Key Decisions

- [0005](../decisions/0005-show-timeline-activity-in-day-planner.md)
- [0006](../decisions/0006-make-planner-timeline-activity-configurable.md)
- [0008](../decisions/0008-confirm-timeline-activity-as-planner-block.md)
- [0087](../decisions/0087-hide-automatic-planner-suggestions.md)
- [0094](../decisions/0094-suggest-only-completed-activity-in-planner-calendar.md)
- [0095](../decisions/0095-drag-tasks-to-planner-all-day-lane.md)
- [0105](../decisions/0105-remove-abandoned-focus-blocks-from-planner.md)
- [0125](../decisions/0125-support-away-sessions.md)
- [0148](../decisions/0148-support-count-up-away-sessions.md)
- [0155](../decisions/0155-link-away-activity-in-planner.md)
- [0191](../decisions/0191-support-one-day-planner-view.md)
- [0205](../decisions/0205-run-plan-focus-from-planner.md)
- [0209](../decisions/0209-allocate-plan-focus-while-running.md)
- [0239](../decisions/0239-link-and-edit-away-sessions.md)
- [0244](../decisions/0244-start-mac-toolbar-focus-with-task-picker.md)
- [0245](../decisions/0245-retire-pending-focus-assignment-ui.md)
- [0267](../decisions/0267-support-mac-toolbar-tag-focus.md)

## Current Contract

- Timeline activity is evidence for completed, missed, canceled, sleep, place, note, emotion, event, and accepted focus activity.
- Planner can surface timeline activity, but automatic suggestions come only from completed activity and may be hidden as presentation state.
- Planner supports a default week view and a focused one-day view without changing stored planner data.
- Planner all-day lanes accept tasks, timed blocks, and completed activity drops.
- Standalone events render as calendar-visible, read-only planner blocks.
- Sleep, Focus, and Away are app-level protected session modes and must not overlap.
- Task, unassigned, and board focus can pause and resume. Active time, not paused wall-clock time, feeds app history and stats.
- Plan focus starts from `Plan to do today`, runs as unassigned focus, and can be allocated to planned tasks while running or after finishing.
- Mac Home toolbar focus duration choices open a picker where users can select a tag to filter tasks, start tag-backed focus, or select a task to start task-backed focus.
- The Mac toolbar no longer offers pending focus assignment, and Stats no longer shows the unassigned focus assignment card by default.
- Away has dedicated history and stats, supports fixed-duration and count-up sessions, and can optionally link to a task.
