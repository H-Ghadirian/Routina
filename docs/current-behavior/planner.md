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
- [0368](../decisions/0368-hide-assumed-done-calendar-layer-by-default.md)
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
- [0302](../decisions/0302-minimize-fullscreen-mac-task-details-to-companion-pane.md)
- [0303](../decisions/0303-align-mac-planner-range-picker-with-adaptive-days.md)
- [0304](../decisions/0304-place-day-spacing-controls-in-time-header.md)
- [0305](../decisions/0305-hide-planner-range-picker-when-header-cannot-fit.md)
- [0306](../decisions/0306-use-day-planner-width-for-task-detail-inspector-fit.md)
- [0307](../decisions/0307-hide-planner-range-picker-in-day-inspector-layout.md)
- [0309](../decisions/0309-show-full-timeline-in-planner-list-mode.md)
- [0312](../decisions/0312-move-mac-task-timeline-filter-entry-to-toolbar.md)
- [0318](../decisions/0318-remove-mac-home-timeline-toolbar-segment.md)
- [0325](../decisions/0325-rename-planner-list-segment-to-timeline.md)
- [0341](../decisions/0341-consolidate-mac-home-toolbar-row.md)
- [0342](../decisions/0342-use-single-date-jump-in-planner-timeline.md)
- [0367](../decisions/0367-show-day-agenda-done-sections.md)
- [0369](../decisions/0369-show-day-task-list-columns-in-planner-calendar.md)

## Current Contract

- Timeline activity is evidence for completed, missed, canceled, sleep, place, note, emotion, event, and accepted focus activity.
- Timeline list surfaces show newest activity first in normal, non-inverted lists, with date headers above their rows.
- Mac Planner can switch its main area with a `Calendar` / `Timeline` segmented control. Calendar mode preserves the Planner Calendar filters, date picker sidebar, and range controls, and has its own `Schedule` / `List` task-view control. `Schedule` is the editable timed Planner grid with all-day lane, Needs Time lane, slot actions, current-time indicators, drag/drop, resize interactions, and day-header task buttons. `List` keeps the same visible date columns, hides the day-header task buttons, and replaces time layers with read-only per-day task agenda columns using the same `Planned tasks`, `Assumed done`, and `Dones` row presentation as the day task sidebar; those columns do not provide drag payloads. Switching to `List` clears in-progress schedule-only draft, drag/drop, and resize state. The `Timeline` segment selects the existing list-mode surface, replacing the main area with Timeline-style entries that use newest-first Timeline ordering and the Home Timeline filters without changing stored Planner blocks or timeline records. When active Timeline filters hide newer activity while older matching rows remain visible, Planner Timeline shows an active-filter notice with a direct clear action above the rows. On Mac, Planner `Timeline` is the normal toolbar route for reviewing the full timeline; Timeline is no longer a visible Home toolbar mode-strip segment.
- On Mac, the Home toolbar search filters task-backed Planner Calendar presentation, including planned task blocks, all-day task items, day-header task counters, and day agenda/List timeline task rows, without mutating Planner storage or calendar layer filter state.
- Planner can derive timeline task activity for day agenda and Calendar `List` review, but the editable Calendar `Schedule` only renders task-backed blocks that come from explicit Planner placements, all-day task placements, or exact task schedules derived from task date/time metadata. Recorded completions and synthetic assumed-done activity do not appear as timed Schedule blocks, Needs Time blocks, or completed-derived all-day pills after a user marks a task done.
- Assumed-done planner activity is synthetic: it uses the routine's probable done time for day agenda/List placement and does not create completion history until the user confirms the routine day.
- Exact-time and time-window routines create timed Planner blocks at their scheduled start. If a time-window routine has no duration estimate, Planner uses the window length for the block duration before falling back to the generic one-hour default; an explicit duration estimate still controls the block duration.
- Protected Away, Focus, and Sleep intervals remain separate from task Schedule blocks and keep their existing suppression/linking behavior for overlapping timeline activity.
- Planner supports `Day`, `3 Days`, and `Week` ranges without changing stored planner data. On macOS, the selected range segment follows the effective width-adaptive range when the segmented picker is visible: a preferred Week range can display Week, 3 Days, or Day depending on calendar width, while an explicitly selected Day range stays pinned when the window grows. When a right-side companion pane is open, the adaptive range stays capped to Day until the remaining Planner calendar column reaches the roomy inspector width needed for multi-day layout.
- Planner Day mode can increase or decrease hour-row spacing for more precise block placement, while 3 Days and Week keep the standard compact hour height.
- Planner has one canonical header date/range control in the right utility cluster. It shows the selected day in Day mode, shows the effective visible range in 3 Days or Week mode, and opens date selection in the right Planner sidebar when pressed. Show today appears only when today's column is outside the visible calendar; previous/next moves by the effective visible range. On macOS, Calendar/Timeline, the Planner filter button, and Day/3 Days/Week stay grouped with navigation/view controls only when the measured full header row fits and any companion-pane layout has roomy inspector width. When that row cannot fit, when the companion-pane layout is tight, or when the task-detail companion pane is open and the effective Planner range is Day, the range picker is hidden so previous/next, display mode, filter, and date/range controls stay on one row. That range-picker breakpoint does not by itself make Calendar/Timeline icon-only or cap the date/range text; when the header narrows further, Calendar/Timeline text hides before the date/range button switches to its compact width. When the Timeline segment is selected, the Calendar/Timeline switch, Planner filter button, and Go to date button remain visible while Today, previous/next, and Day/3 Days/Week are hidden because the main list is not scoped to the Planner range. Pressing Go to date in Timeline uses a single selected date, opens the right-side Planner date picker, updates the selected Planner date, and scrolls to the matching visible Timeline day when that day exists without filtering the Timeline list. In Day mode, the hour spacing controls live inside the calendar `Time` header cell.
- Planner all-day lanes accept task drops and timed-block drops.
- Each Planner day header has a day-task button with one compact total count. Pressing it opens the right-side Planner sidebar for that date with `Planned tasks`, `Assumed done`, and `Dones` sections; the category breakdown appears in the button help/accessibility text and in those sidebar section headers. Rows in this right-side sidebar can be dragged into the editable Schedule grid or all-day lane using the same task payload as left-sidebar task rows. `Planned tasks` includes active date-only `Plan to do` tasks, task-backed all-day planner items, and timed task blocks sorted by start time. Date-only planned rows do not create stored Planner blocks, deduplicate against visible all-day or timed items for the same task, respect the all-day task visibility filter, and exclude daily routines, completed/canceled one-off tasks, archived or snoozed tasks, and pinned tasks. `Assumed done` shows matching synthetic assumed-done Planner activity in the sidebar even when the timed Calendar `Assumed done` layer is disabled, and `Dones` shows visible recorded completed Planner activity, including completion-log rows and `lastDone` fallback activity. These done sections follow Calendar search, task filters, individual activity hiding, and the timeline-suggestion layer. Hovering an assumed-done row on Mac shows inline green check and red x actions: the check confirms the assumed day as completed, and the x records it as missed. The list excludes standalone events, Away, Sleep, Focus intervals, and other protected-session blocks.
- Opening a task while Planner is active, whether from the left task list or from Planner itself, keeps Planner visible and shows task details in a companion pane on the right side of the Mac detail area when the detail area can fit the fixed companion pane plus a Day-capable Planner surface. At tight widths, the Planner calendar can adapt down to a compact Day layout with a narrower day column to make room for the pane. The pane has close and fullscreen controls; fullscreen switches to the regular Details surface for the selected task. Full Details opened from that control can minimize back to the previous companion-pane layout, while its separate close control returns to Planner and clears the pane. Planner's own right sidebar remains reserved for slot actions, day agendas, and date selection. Only one right-side secondary surface can be open in the Mac detail area: opening task details closes Planner's internal right sidebar, and opening Planner's internal right sidebar closes task details. Double-clicking a Mac task-list row opens the selected task in the full Details surface instead of the companion pane.
- Planner has a compact header filter button in both Calendar and Timeline modes. Pressing it opens the right-side Home filter companion pane with `All`, `Task List`, `Timeline`, and `Calendar` tabs, selecting `Calendar` by default. The `Calendar` tab has presentation-only layer toggles for timed planned tasks, all-day tasks, timeline suggestions, assumed done, Events when Mac Event/Emotion actions are enabled, Focus, and Away/Sleep when `Show Away` is enabled. The timeline and assumed-done toggles affect day agenda/List review rows, not completed-task Schedule blocks. Disabled beta-layer filters are omitted and stale hidden state for unavailable layers is ignored. Calendar filters only hide or show visible Planner layers; they do not mutate task, event, session, drop-validation, planner-block records, or the Planner Timeline list range.
- Single-clicking an empty timed Planner slot selects the clicked 15-minute date/time without starting creation. Double-clicking an empty timed Planner slot shows a temporary resizable draft block and opens a right-side Planner sidebar for creating a task block. The task sidebar uses an inline filtered task list and can create a new one-off task before adding the block; when task creation is the only available action, it does not show a single-option mode tab. When `Show Away` is on, the sidebar also offers an Away tab for logging finished screen-away time; that tab presents Away presets plus Sleep. Away choices create completed `AwaySession` records, while Sleep creates a completed `SleepSession`. When `Show Away` is off, the empty-slot action sidebar does not show Away or Sleep options. While the sidebar is open, selecting another empty timed slot moves the draft and sidebar to that slot. Resizing the draft updates the displayed time range and duration before commit.
- Deleting a task removes persisted planner blocks for that task and refreshes open Planner state; automatic timeline suggestions, focus history, Away, Sleep, events, and unrelated planner blocks remain governed by their own models.
- Standalone events render as calendar-visible, read-only planner blocks.
- Sleep, Focus, and Away are app-level protected session modes and must not overlap.
- Task, unassigned, and board focus can pause and resume. Active time, not paused wall-clock time, feeds app history and stats.
- Plan focus starts from `Today`, runs as unassigned focus, and can be allocated to planned tasks while running or after finishing.
- The Mac Planner Calendar header Focus control opens a picker where users can select a tag to filter tasks, start tag-backed focus, or select a task to start task-backed focus.
- The Mac toolbar no longer offers pending focus assignment, and Stats no longer shows the unassigned focus assignment card by default.
- Away has dedicated history and stats, supports fixed-duration and count-up sessions, and can optionally link to a task.
