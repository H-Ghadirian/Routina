# Regression Scenarios

This directory records app behaviors that must not quietly break again.

Use decision records for why a durable choice exists. Use current-behavior pages for what the app should currently do. Use scenarios here for concrete Given/When/Then expectations that should be protected by tests.

## Rule

A recurring bug fix is not complete until the expected behavior is captured as a scenario and covered by at least one automated test.

## Scenario Format

```md
## Scenario Name

Area: Tasks / Planner / Stats / Settings / Places / Other
Decision links: 0249
Current behavior: ../current-behavior/tasks.md
Coverage:
- Tests/Shared/ExampleTests.swift
- Tests/macOS/ExampleFeatureTests.swift

Given ...
When ...
Then ...
```

If coverage does not exist yet, write `Coverage needed:` instead of `Coverage:` and add the test in the same change whenever practical.

## Initial High-Value Scenarios

### Custom Buttons Use Full Visual Hit Areas

Area: Other
Decision links: [0264](../decisions/0264-match-button-hit-areas-to-visual-surfaces.md)
Current behavior: [UI](../current-behavior/ui.md)
Coverage needed:
- UI-level verification that custom/plain SwiftUI buttons respond across their full visible card, chip, row, or pill surface.

Given a custom or plain SwiftUI button has a visible padded card, chip, row, or pill surface
When the user taps or clicks inside that visible surface but outside the text, emoji, or icon glyphs
Then the button action still runs

### Mac Toolbar Search Does Not Steal Editor Focus

Area: Other
Decision links: [0310](../decisions/0310-show-mac-home-toolbar-search.md)
Current behavior: [UI](../current-behavior/ui.md)
Coverage:
- `Tests/macOS/PerformanceRegressionTests.swift`

Given Mac Home search has triggered a toolbar search update
When the user moves focus into a task comment, note, or other text editor before the delayed search-focus repair completes
Then typing stays in that editor instead of jumping back to the toolbar search field

### Mac Toolbar Search Expands as One Visible Pill

Area: Other
Decision links: [0321](../decisions/0321-use-focus-expanded-mac-home-toolbar-search.md), [0323](../decisions/0323-draw-mac-toolbar-search-shell-in-swiftui.md), [0327](../decisions/0327-animate-mac-toolbar-search-as-one-visible-pill.md)
Current behavior: [UI](../current-behavior/ui.md)
Coverage:
- `Tests/macOS/PerformanceRegressionTests.swift`

Given the Mac Home toolbar search field is compact and idle
When the user focuses the field and it expands to the focused width
Then the principal toolbar item keeps an active invisible host so AppKit does not keep old and new search placements onscreen
And idle search shows only the compact pill instead of drawing a second full-width oval behind it
And the SwiftUI search shell, icon, typed text, placeholder, clear button, create hint, and `Esc` keycap animate as one visible search surface
And clicking outside the visible search pill dismisses focus and collapses search without making the invisible host steal nearby toolbar clicks
And the host releases back to compact width after collapse so task-detail toolbar actions remain visible
And the field remains clickable and editable throughout the animation

### Mac Toolbar Search Creates Only When Search Has No Result

Area: Other
Decision links: [0315](../decisions/0315-merge-mac-quick-add-into-toolbar-search.md)
Current behavior: [UI](../current-behavior/ui.md)
Coverage:
- `Tests/macOS/PerformanceRegressionTests.swift`

Given the configurable Mac Quick Add shortcut has focused the Home toolbar search field
When the user enters a non-empty query and presses Return
Then Routina creates a task through Quick Add only if that query has no matching task or Timeline-style result
And the toolbar shows a visible Return-to-create hint for that no-result query
And if the query includes quick-add syntax such as `today`, `every day`, or `#home`, the toolbar shows a flat same-width parser preview below the field before creation without duplicating the Return-to-create hint

### Daily Checklist Progress Resets

Area: Tasks
Decision links: [0249](../decisions/0249-reset-daily-checklist-progress.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/iOS/HomeFeatureTests.swift`
- `Tests/Shared/TaskDetailFeatureCompletionTests.swift`

Given a daily checklist-completion routine has partially checked items today
When the app derives routine state tomorrow
Then stale partial checklist progress is ignored and the next day starts unchecked

### Completed Daily Checklist Ignores Stale Partial Progress

Area: Tasks
Decision links: [0249](../decisions/0249-reset-daily-checklist-progress.md), [0253](../decisions/0253-guard-checklist-detail-mutations-through-reloads.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/HomeRoutineDisplayFactoryTests.swift`
- `Tests/Shared/HomeTaskHelperTests.swift`
- `Tests/Shared/SwiftDataModelTests.swift`
- `Tests/Shared/TaskDetailFeatureCompletionTests.swift`

Given a daily checklist-completion routine has a completed log for today and stale partial checklist-progress IDs
When the app derives Home or Task Detail checklist state for today, receives the final checklist item tap followed by a stale Home task reload, receives a duplicate checklist item toggle, or receives stale completed task/log evidence after Undo
Then stale or cleared in-progress IDs are ignored, completed-day checklist rows stay checked/read-only without blinking unchecked first, and Undo keeps rows unchecked without flashing back to completed

### Checklist Runout Past-Day Updates

Area: Tasks
Decision links: [0240](../decisions/0240-keep-checklist-runout-item-actions-item-scoped.md), [0328](../decisions/0328-allow-past-day-checklist-runout-updates.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/HomeTaskHelperTests.swift`
- `Tests/Shared/TaskDetailFeatureCompletionTests.swift`
- `Tests/Shared/TaskDetailSharedViewSupportTests.swift`

Given a checklist runout routine has an item due yesterday
When the user selects yesterday in Task Details and checks that item
Then the item is reset using yesterday as the done date, the selected-day row appears checked, and future selected dates remain unavailable for runout updates

### Daily Checklist Auto-Assume Uses Day-Level Completion

Area: Tasks
Decision links: [0259](../decisions/0259-allow-daily-checklist-auto-assumed-completion.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/RoutineAssumedCompletionTests.swift`
- `Tests/Shared/HomeRoutineDisplayFactoryTests.swift`
- `Tests/Shared/TaskDetailFeatureCompletionTests.swift`

Given a daily checklist-completion routine has auto-assume done enabled
When today's availability starts and no checklist item progress exists
Then Home and Task Detail present the routine as assumed done without pretending individual checklist items are checked

Given a daily routine is created today with auto-assume done enabled
When today's availability has already started
Then Home treats the current occurrence as assumed done while dates before creation remain unassumed

Given the user starts checking checklist items for that daily occurrence
When the app derives assumed completion state
Then manual partial checklist progress suppresses assumed-done presentation until the routine is fully completed or progress is cleared

### Planner Shows Assumed Done Routines

Area: Planner
Decision links: [0268](../decisions/0268-show-assumed-done-routines-in-planner.md)
Current behavior: [UI](../current-behavior/ui.md)
Coverage:
- `Tests/Shared/DayPlanPlannerStateTests.swift`

Given an eligible daily routine has auto-assume done enabled
When Planner derives automatic activity for an assumed-done day
Then the routine appears as completed planner activity without creating a completion log

Given the user hides that assumed-done planner activity
When Planner derives automatic activity again
Then the synthetic assumed-done activity stays hidden for that task and day

### New Routine Checklists Use Checklist Completion

Area: Tasks
Decision links: [0263](../decisions/0263-promote-new-routine-checklists-to-checklist-completion.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskDetailEditSaveTests.swift`
- `Tests/Shared/TaskDetailCommentsTests.swift`

Given a Standard routine has no checklist items
When the user adds checklist items in Task Details
Then the editor and save path promote it to Checklist completion so eligible daily routines can expose auto-assume done

Given an existing Standard routine already has checklist items from legacy optional data
When the user saves it from Task Details
Then the app preserves the Standard completion mode unless the user explicitly changes it

### Late Completion Stops Overdue Calendar Markers

Area: Tasks
Decision links: [0200](../decisions/0200-support-task-planned-dates.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskDetailCalendarGridSupportTests.swift`

Given a todo was due on June 25 and is logged done on June 26 after the fact
When Task Detail renders the June calendar on June 29
Then June 25 can remain overdue, June 26 shows done, and June 27 through June 29 do not stay overdue

### Selected Timed Occurrence Can Be Resolved After Prior Occurrence

Area: Tasks
Decision links: [0003](../decisions/0003-resolve-exact-time-missed-assumptions.md), [0009](../decisions/0009-support-routine-time-ranges.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskDetailFeatureCompletionTests.swift`

Given a weekly time-window routine has an earlier occurrence already resolved as canceled
When the user selects a later missed occurrence in Task Detail and presses Done
Then Routina records a completed log for the selected occurrence without treating the earlier resolved occurrence as a blocker

### Multi-Day Routine Lifecycle

Area: Tasks
Decision links: [0199](../decisions/0199-support-multiday-routine-start-flow.md), [0246](../decisions/0246-show-multiday-ongoing-range.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskDetailFeatureCompletionTests.swift`
- `Tests/Shared/TaskDetailCalendarGridSupportTests.swift`

Given a multi-day routine has not started
When the user starts it, views it while active, stops it, and undoes completion
Then the primary action, active range, completed span, and undo behavior stay consistent

### Today Routines Stay In Today Section

Area: Tasks
Decision links: [0202](../decisions/0202-nest-daily-routines-under-mac-plan-today.md), [0247](../decisions/0247-make-mac-daily-routine-grouping-optional.md), [0266](../decisions/0266-show-calendar-routines-in-plan-today.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/macOS/HomeFeatureTaskListModeTests.swift`
- `Tests/iOS/HomeFeatureTaskListModeTests.swift`
- `Tests/Shared/HomeTaskListFilteringTests.swift`

Given Mac Home shows `Today`
When daily routines are loaded with the grouping setting off or on
Then daily routines remain in the today area, visually merged by default and nested only when the setting is enabled

Given Mac Home shows expanded `Today`
When planned rows are visible
Then the header and rows share one full-bleed section surface with square horizontal edges, no colored side borders, and spacing between task cards

Given Mac Home shows expanded `Future`
When future task groups are visible
Then the header and groups share one full-bleed section surface while nested tag groups keep their own collapsible surfaces

Given a weekly or month-day calendar routine is configured for today's weekday or day of month
When Home derives `Today`
Then that calendar routine appears in the existing today list without a separate scheduled-today group, while rolling interval routines stay in the normal due/status sections unless explicitly planned

Given a weekly or month-day calendar routine has a canceled occurrence for today
When Home derives `Today`
Then that routine no longer appears in the today plan for the canceled day

### Future Preserves Inner Group Behavior

Area: Tasks
Decision links: [0283](../decisions/0283-preserve-mac-future-inner-sections.md), [0314](../decisions/0314-remove-status-grouping-and-collapse-deadline-groups.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/HomeTaskListFilteringTests.swift`

Given Mac Home groups regular tasks by tag
When Home derives the `Future` section
Then each tag group remains a tagged, colorable, collapsible inner section inside `Future`

Given Mac Home groups regular tasks by deadline date
When Home derives the `Future` section
Then each deadline-date group remains independently collapsible inside `Future`

### Home Task Lists Keep Stable Row Identity

Area: Tasks
Decision links: [0252](../decisions/0252-stabilize-home-task-list-presentation-identity.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/HomeTaskListFilteringTests.swift`

Given task data briefly appears in overlapping active, away, archived, planned, daily, or status inputs during a refresh
When Home task-list presentation is derived
Then each task ID is claimed once, section and group IDs stay stable, and the UI updates existing rows instead of replacing them

### Planner Filter Button Uses a Companion Pane

Area: UI
Decision links: [0312](../decisions/0312-move-mac-task-timeline-filter-entry-to-toolbar.md), [0316](../decisions/0316-present-mac-home-filters-as-companion-pane.md), [0319](../decisions/0319-open-planner-filters-in-home-filter-pane.md)
Current behavior: [UI](../current-behavior/ui.md)
Coverage:
- `Tests/macOS/PerformanceRegressionTests.swift`

Given Mac Home is showing Planner in Calendar or List mode
When the Planner header filter button is pressed
Then the `Both` / `Task List` / `Timeline` / `Calendar` filter surface opens in a right-side companion pane while the current workspace remains visible
And task-detail panes, the board inspector, and Planner-local right sidebars do not remain open beside it
When the user expands the filter pane fullscreen and then minimizes it
Then the filter surface returns to the right-side companion pane

### Timeline Filters Do Not Auto-Open Row Details

Area: Timeline
Decision links: [0280](../decisions/0280-show-timeline-newest-first.md), [0256](../decisions/0256-move-mac-timeline-row-appearance-to-timeline-filter-detail.md), [0316](../decisions/0316-present-mac-home-filters-as-companion-pane.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/TimelineSelectionSupportTests.swift`
- `Tests/macOS/PerformanceRegressionTests.swift`

Given Mac Home is showing the Timeline filter companion pane
When a filter change updates the visible timeline rows
Then the sidebar does not automatically select a fallback row or close the filter pane until the user explicitly leaves the filter pane or selects a row

### Planner List Honors Home Timeline Filters

Area: Timeline
Decision links: [0309](../decisions/0309-show-full-timeline-in-planner-list-mode.md), [0312](../decisions/0312-move-mac-task-timeline-filter-entry-to-toolbar.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/macOS/PerformanceRegressionTests.swift`

Given Mac Planner is in `List` mode
When the companion filter pane changes shared `Both` filters or Timeline-specific filters
Then the Planner List timeline rows use the same filtered entry set as the Timeline sidebar
And an empty filtered list explains that search or filters may be hiding entries

### Plan Focus Allocation Preserves Focus History

Area: Planner
Decision links: [0205](../decisions/0205-run-plan-focus-from-planner.md), [0209](../decisions/0209-allocate-plan-focus-while-running.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/FocusSessionSupportTests.swift`
- `Tests/Shared/DayPlanPlannerStateTests.swift`

Given plan focus starts from tasks in `Today`
When focus time is allocated while running or after finish
Then task allocations are recorded without deleting the unassigned focus session history

### Planner Range Picker Follows Adaptive Visible Days

Area: Planner
Decision links: [0303](../decisions/0303-align-mac-planner-range-picker-with-adaptive-days.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/DayPlanPlannerStateTests.swift`

Given Mac Planner prefers Week mode
When the calendar column becomes wide, medium, or narrow
Then the selected range segment and rendered calendar become Week, 3 Days, or Day respectively and previous/next navigation moves by that effective visible range

Given the user explicitly selects Day
When the calendar column grows from narrow to wide
Then Planner keeps Day selected and continues rendering one day

### Planner Companion Panes Do Not Overlap Calendar

Area: Planner
Decision links: [0296](../decisions/0296-present-mac-task-details-as-planner-inspector.md), [0299](../decisions/0299-constrain-mac-home-window-size.md), [0306](../decisions/0306-use-day-planner-width-for-task-detail-inspector-fit.md), [0307](../decisions/0307-hide-planner-range-picker-in-day-inspector-layout.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/DayPlanPlannerStateTests.swift`
- `Tests/macOS/PerformanceRegressionTests.swift`

Given Mac Planner is visible beside a right-side companion pane
When the available Planner column becomes tight
Then Mac Home subtracts the fixed companion pane before sizing the Planner column, clips Planner content to that column, and caps the adaptive Planner range to Day until the remaining calendar column is roomy enough for multi-day inspector layout

### Planner Block Resize Stays Continuous Across Layout Changes

Area: Planner
Decision links: [0264](../decisions/0264-match-button-hit-areas-to-visual-surfaces.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/DayPlanPlannerStateTests.swift`

Given a manual planner block is selected
When the user drags the top or bottom resize grip and the block crosses a height threshold that changes its card presentation
Then the active drag continues resizing the block to its live size and position without requiring the user to release and grab the grip again

### Small Planner Blocks Remain Movable

Area: Planner
Decision links: [0264](../decisions/0264-match-button-hit-areas-to-visual-surfaces.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/DayPlanPlannerStateTests.swift`

Given a manual planner block is short, such as a 5- or 15-minute block
When the user hovers or drags from the middle of the block
Then the block can still be moved because resize grips stay limited to the block edges

### Deleting a Task Removes Its Planner Blocks

Area: Planner, Tasks
Decision links: [0287](../decisions/0287-remove-deleted-task-blocks-from-planner.md)
Current behavior: [Planner](../current-behavior/planner.md), [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/DayPlanStorageTests.swift`
- `Tests/iOS/TaskDetailFeatureTests.swift`
- `Tests/macOS/TaskDetailFeatureTests.swift`

Given a task has a persisted planner block
When the user deletes that task from edit task
Then matching planner blocks are removed from Planner storage and unrelated planner blocks remain

### Planner Slot Actions Hide Away and Sleep When Away Is Off

Area: Planner
Decision links: [0277](../decisions/0277-hide-notes-and-away-behind-beta-toggles.md), [0279](../decisions/0279-hide-sleep-stats-and-blocking-with-away-toggle.md), [0273](../decisions/0273-log-sleep-from-planner-away-slot-action.md), [0286](../decisions/0286-present-planner-slot-actions-in-sidebar.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/DayPlanSlotActionPresentationTests.swift`

Given Support & About -> Beta Experiments -> `Show Away` is off
When the user opens the Planner empty-slot action sidebar
Then the panel offers task block creation only and does not expose Away or Sleep logging options

Given the Planner empty-slot action sidebar has only task block creation available
When the sidebar opens for the draft block
Then it does not show a single-option `Task` tab, keeps the draft block visible in the grid, lets the user select a task from an inline filtered list, and can create a new task before adding the block

### Planner Calendar Filters Respect Beta Toggles

Area: Planner
Decision links: [0291](../decisions/0291-gate-planner-calendar-filter-options-by-beta-toggles.md), [0289](../decisions/0289-filter-planner-calendar-layers.md), [0319](../decisions/0319-open-planner-filters-in-home-filter-pane.md), [0277](../decisions/0277-hide-notes-and-away-behind-beta-toggles.md), [0220](../decisions/0220-nest-sleep-and-gate-mac-event-emotion-actions.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/DayPlanCalendarFilterStateTests.swift`

Given Support & About -> Beta Experiments -> `Show Away` is off
When the user opens the companion filter pane's `Calendar` tab
Then the panel does not expose Away or Sleep filter options

Given Support & About -> Beta Experiments -> `Show Event and Emotion actions` is off
When the user opens the companion filter pane's `Calendar` tab
Then the panel does not expose an Events filter option

Given stale hidden filter state exists for Events, Away, or Sleep from a previous beta-enabled session
When the relevant beta toggle is off
Then those unavailable beta layers do not count as active hidden filters or stay hidden without a visible control

### Planner Inspector Day Header Hides Range Picker

Area: Planner
Decision links: [0305](../decisions/0305-hide-planner-range-picker-when-header-cannot-fit.md), [0306](../decisions/0306-use-day-planner-width-for-task-detail-inspector-fit.md), [0307](../decisions/0307-hide-planner-range-picker-in-day-inspector-layout.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/DayPlanPlannerStateTests.swift`

Given the Mac Planner task-detail companion pane is open
When the effective Planner range has adapted down to Day
Then the top `Day` / `3 Days` / `Week` segmented picker is hidden while Calendar/List, previous/next, filter, and the full date/range controls remain in the header
And the calendar grid can use its compact inspector minimum width so the time column and single day column fit inside the Planner surface

Given the Mac Planner task-detail companion pane is open and the range picker is already hidden
When the Planner header becomes narrower
Then the Calendar/List segment hides text before the date/range button switches to compact width

Given the Mac Planner task-detail companion pane is open with enough room for a multi-day effective range
When the full header controls fit on one row
Then the top range segmented picker can remain visible

### Planner Day Headers Open Planned Task Lists

Area: Planner
Decision links: [0288](../decisions/0288-open-planned-day-task-list-from-planner-headers.md), [0300](../decisions/0300-show-plan-to-do-tasks-in-planner-day-agenda.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/DayPlanDayTaskListPresentationTests.swift`

Given a Planner day has all-day task blocks, timed task blocks, standalone events, and protected-session blocks
When the user opens the day header's planned-task list
Then the right sidebar shows task-backed all-day items followed by timed task blocks for that date, and excludes events and protected sessions

Given a task has only a date-only `Plan to do` value for Monday
When the user opens Monday's Planner planned-task list
Then the task appears in the all-day portion of the list without creating a stored Planner block or duplicating any visible all-day or timed item for the same task

### Protected Modes Do Not Overlap

Area: Planner
Decision links: [0012](../decisions/0012-model-sleep-as-app-level-session-mode.md), [0125](../decisions/0125-support-away-sessions.md), [0158](../decisions/0158-generalize-protected-mode-blocking-settings.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/SleepSessionSupportTests.swift`
- `Tests/Shared/AwaySessionSupportTests.swift`
- `Tests/Shared/FocusSessionSupportTests.swift`

Given Sleep, Focus, or Away is active
When another protected mode is requested
Then the app prevents overlapping protected sessions and keeps history unambiguous

### Empty Stats Reports Stay Hidden

Area: Stats
Decision links: [0236](../decisions/0236-hide-empty-stats-reports.md)
Current behavior: [Stats](../current-behavior/stats.md)
Coverage:
- `Tests/Shared/StatsFeatureDerivedStateSupportTests.swift`
- `Tests/macOS/StatsMacDashboardItemAvailabilityTests.swift`
- `Tests/iOS/StatsDashboardItemAvailabilityTests.swift`

Given a dashboard report has no backing data
When Stats summary items are derived
Then the report is hidden while saved order and hidden-item preferences remain preserved

### App Lock Protects Sensitive Reset Actions

Area: Settings
Decision links: [0166](../decisions/0166-use-app-lock-for-cloud-data-reset.md), [0235](../decisions/0235-require-authentication-to-disable-app-lock.md), [0241](../decisions/0241-gate-settings-reset-with-app-lock.md)
Current behavior: [Settings](../current-behavior/settings.md)
Coverage:
- `Tests/Shared/SettingsFeatureTests.swift`

Given a user tries to disable App Lock or restore settings defaults
When device-owner authentication fails, is unavailable, or App Lock is off where required
Then the sensitive action does not proceed

### Saved-Place Map Actions Stay Contextual

Area: Places
Decision links: [0230](../decisions/0230-unify-map-pin-place-and-check-in-actions.md), [0232](../decisions/0232-allow-known-pin-check-in.md), [0233](../decisions/0233-allow-selected-saved-place-check-in.md), [0234](../decisions/0234-hide-current-place-map-check-in.md)
Current behavior: [Places](../current-behavior/places.md)
Coverage:
- `Tests/iOS/PlaceLocationPickerCameraConfigurationTests.swift`
- `Tests/macOS/PlaceLocationPickerCameraConfigurationTests.swift`
- `Tests/Shared/PlaceCheckInSupportTests.swift`

Given the map is showing an unsaved location, an away saved place, or the current resolved saved place
When the action panel is derived
Then Add Place and Check In appear only for the contexts where they make sense
