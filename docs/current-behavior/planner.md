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
- [0286](../decisions/0286-present-planner-slot-actions-in-sidebar.md)
- [0277](../decisions/0277-hide-notes-and-away-behind-beta-toggles.md)
- [0279](../decisions/0279-hide-sleep-stats-and-blocking-with-away-toggle.md)
- [0280](../decisions/0280-show-timeline-newest-first.md)
- [0282](../decisions/0282-expand-day-planner-hour-spacing.md)
- [0287](../decisions/0287-remove-deleted-task-blocks-from-planner.md)
- [0288](../decisions/0288-open-planned-day-task-list-from-planner-headers.md)
- [0289](../decisions/0289-filter-planner-calendar-layers.md)
- [0291](../decisions/0291-gate-planner-calendar-filter-options-by-beta-toggles.md)
- [0292](../decisions/0292-unify-planner-header-date-control.md)
- [0296](../decisions/0296-present-mac-task-details-as-planner-inspector.md)
- [0297](../decisions/0297-open-mac-task-rows-fullscreen-on-double-click.md)
- [0299](../decisions/0299-constrain-mac-home-window-size.md)
- [0300](../decisions/0300-show-plan-to-do-tasks-in-planner-day-agenda.md)
- [0301](../decisions/0301-adapt-mac-planner-week-visible-days.md)
- [0302](../decisions/0302-minimize-fullscreen-mac-task-details-to-companion-pane.md)

## Current Contract

- Timeline activity is evidence for completed, missed, canceled, sleep, place, note, emotion, event, and accepted focus activity.
- Timeline list surfaces show newest activity first in normal, non-inverted lists, with date headers above their rows.
- Planner can surface timeline activity, but automatic suggestions come only from completed activity and eligible assumed-done routine days, and may be hidden as presentation state.
- Assumed-done planner activity is synthetic: it uses the routine's probable done time for planner placement, can be hidden from Planner or converted into a planner block, and does not create completion history until the user confirms the routine day.
- Automatic activity that cannot be placed because planner task or event blocks reserve the usable time appears in the top `Needs Time` lane for that day, where it can be dragged into the timed calendar, hidden, confirmed, or opened like other automatic activity.
- Protected Away, Focus, and Sleep intervals remain separate from the `Needs Time` lane and keep their existing suppression/linking behavior for overlapping automatic activity.
- Planner supports a width-adaptive Week view and a focused Day view without changing stored planner data. On macOS, Week mode shows seven, three, or one visible day based on available calendar width.
- Planner Day mode can increase or decrease hour-row spacing for more precise block placement, while Week mode keeps the standard compact hour height even when adaptive Week narrows to one visible day.
- Planner has one canonical header date/range control in the right utility cluster. It shows the selected day in Day mode, shows the effective visible range in Week mode, and opens date selection in the right Planner sidebar when pressed. Show today appears only when today's column is outside the visible calendar; previous/next moves by the effective visible range, while Day/Week and Day spacing controls stay grouped as navigation/view controls on the left.
- Planner all-day lanes accept tasks, timed blocks, and completed activity drops.
- Each Planner day header has a compact planned-task list button. Pressing it opens the right-side Planner sidebar for that date with active date-only `Plan to do` tasks, task-backed all-day planner items, and timed task blocks sorted by start time. Date-only planned rows do not create stored Planner blocks, deduplicate against visible all-day or timed items for the same task, respect the all-day task visibility filter, and exclude daily routines, completed/canceled one-off tasks, archived or snoozed tasks, and pinned tasks. The list excludes standalone events, Away, Sleep, Focus intervals, and other protected-session blocks.
- Opening a task while Planner is active, whether from the left task list or from Planner itself, keeps Planner visible and shows task details in a companion pane on the right side of the Mac detail area when the detail area can fit both surfaces. The pane has close and fullscreen controls; fullscreen switches to the regular Details surface for the selected task. Full Details opened from that control can minimize back to the previous companion-pane layout, while its separate close control returns to Planner and clears the pane. Planner's own right sidebar remains reserved for slot actions, day agendas, filters, and date selection. Only one right-side secondary surface can be open in the Mac detail area: opening task details closes Planner's internal right sidebar, and opening Planner's internal right sidebar closes task details. Double-clicking a Mac task-list row opens the selected task in the full Details surface instead of the companion pane.
- Planner has a compact header filter button. Pressing it opens the right-side Planner sidebar with presentation-only calendar layer toggles for timed planned tasks, all-day tasks, timeline suggestions, Events when Mac Event/Emotion actions are enabled, Focus, and Away/Sleep when `Show Away` is enabled. Disabled beta-layer filters are omitted and stale hidden state for those unavailable layers is ignored. The filters only hide or show visible Planner layers; they do not mutate task, event, session, drop-validation, or planner-block records. Opening filters closes other Planner right-sidebar modes, and opening slot actions or a day task list closes filters.
- Single-clicking an empty timed Planner slot selects the clicked 15-minute date/time without starting creation. Double-clicking an empty timed Planner slot shows a temporary resizable draft block and opens a right-side Planner sidebar for creating a task block. The task sidebar uses an inline filtered task list and can create a new one-off task before adding the block; when task creation is the only available action, it does not show a single-option mode tab. When `Show Away` is on, the sidebar also offers an Away tab for logging finished screen-away time; that tab presents Away presets plus Sleep. Away choices create completed `AwaySession` records, while Sleep creates a completed `SleepSession`. When `Show Away` is off, the empty-slot action sidebar does not show Away or Sleep options. While the sidebar is open, selecting another empty timed slot moves the draft and sidebar to that slot. Resizing the draft updates the displayed time range and duration before commit.
- Deleting a task removes persisted planner blocks for that task and refreshes open Planner state; automatic timeline suggestions, focus history, Away, Sleep, events, and unrelated planner blocks remain governed by their own models.
- Standalone events render as calendar-visible, read-only planner blocks.
- Sleep, Focus, and Away are app-level protected session modes and must not overlap.
- Task, unassigned, and board focus can pause and resume. Active time, not paused wall-clock time, feeds app history and stats.
- Plan focus starts from `Today`, runs as unassigned focus, and can be allocated to planned tasks while running or after finishing.
- Mac Home toolbar focus duration choices open a picker where users can select a tag to filter tasks, start tag-backed focus, or select a task to start task-backed focus.
- The Mac toolbar no longer offers pending focus assignment, and Stats no longer shows the unassigned focus assignment card by default.
- Away has dedicated history and stats, supports fixed-duration and count-up sessions, and can optionally link to a task.
