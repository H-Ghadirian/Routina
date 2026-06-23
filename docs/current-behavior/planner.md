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
- [0268](../decisions/0268-show-assumed-done-routines-in-planner.md)
- [0269](../decisions/0269-support-planner-slot-actions.md)
- [0271](../decisions/0271-use-probable-times-for-assumed-planner-activity.md)
- [0273](../decisions/0273-log-sleep-from-planner-away-slot-action.md)
- [0274](../decisions/0274-present-resizable-planner-slot-draft.md)

## Current Contract

- Timeline activity is evidence for completed, missed, canceled, sleep, place, note, emotion, event, and accepted focus activity.
- Planner can surface timeline activity, but automatic suggestions come only from completed activity and eligible assumed-done routine days, and may be hidden as presentation state.
- Assumed-done planner activity is synthetic: it uses the routine's probable done time for planner placement, can be hidden from Planner or converted into a planner block, and does not create completion history until the user confirms the routine day.
- Automatic activity that cannot be placed because planner task or event blocks reserve the usable time appears in the top `Needs Time` lane for that day, where it can be dragged into the timed calendar, hidden, confirmed, or opened like other automatic activity.
- Protected Away, Focus, and Sleep intervals remain separate from the `Needs Time` lane and keep their existing suppression/linking behavior for overlapping automatic activity.
- Planner supports a default week view and a focused one-day view without changing stored planner data.
- Planner all-day lanes accept tasks, timed blocks, and completed activity drops.
- Single-clicking an empty timed Planner slot selects the clicked 15-minute date/time without starting creation. Double-clicking an empty timed Planner slot shows a temporary resizable draft block and opens a compact action panel anchored to that draft for creating a task block or logging finished screen-away time. On macOS this panel is a native popover so it can remain visible near app edges instead of being clipped by the planner viewport; late-day slots can open the popover above the draft, and the anchor shifts within the visible screen frame so bottom-right fullscreen presentations remain usable. Resizing the draft updates the displayed time range and duration before commit. The Away tab presents Away presets plus Sleep; Away choices create completed `AwaySession` records, while Sleep creates a completed `SleepSession`.
- Standalone events render as calendar-visible, read-only planner blocks.
- Sleep, Focus, and Away are app-level protected session modes and must not overlap.
- Task, unassigned, and board focus can pause and resume. Active time, not paused wall-clock time, feeds app history and stats.
- Plan focus starts from `Plan to do today`, runs as unassigned focus, and can be allocated to planned tasks while running or after finishing.
- Mac Home toolbar focus duration choices open a picker where users can select a tag to filter tasks, start tag-backed focus, or select a task to start task-backed focus.
- The Mac toolbar no longer offers pending focus assignment, and Stats no longer shows the unassigned focus assignment card by default.
- Away has dedicated history and stats, supports fixed-duration and count-up sessions, and can optionally link to a task.
