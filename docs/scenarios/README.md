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

### Daily Routines Stay In Plan To Do Today

Area: Tasks
Decision links: [0202](../decisions/0202-nest-daily-routines-under-mac-plan-today.md), [0247](../decisions/0247-make-mac-daily-routine-grouping-optional.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/macOS/HomeFeatureTaskListModeTests.swift`
- `Tests/iOS/HomeFeatureTaskListModeTests.swift`

Given Mac Home shows `Plan to do today`
When daily routines are loaded with the grouping setting off or on
Then daily routines remain in the today area, visually merged by default and nested only when the setting is enabled

### Home Task Lists Keep Stable Row Identity

Area: Tasks
Decision links: [0252](../decisions/0252-stabilize-home-task-list-presentation-identity.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/HomeTaskListFilteringTests.swift`

Given task data briefly appears in overlapping active, away, archived, planned, daily, or status inputs during a refresh
When Home task-list presentation is derived
Then each task ID is claimed once, section and group IDs stay stable, and the UI updates existing rows instead of replacing them

### Timeline Filters Do Not Auto-Open Row Details

Area: Timeline
Decision links: [0242](../decisions/0242-show-timeline-sections-top-down.md), [0256](../decisions/0256-move-mac-timeline-row-appearance-to-timeline-filter-detail.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/TimelineSelectionSupportTests.swift`

Given Mac Home is showing the Timeline filter detail
When a filter change updates the visible timeline rows
Then the sidebar does not automatically select a fallback row or close the filter detail until the user explicitly leaves the filter detail or selects a row

### Plan Focus Allocation Preserves Focus History

Area: Planner
Decision links: [0205](../decisions/0205-run-plan-focus-from-planner.md), [0209](../decisions/0209-allocate-plan-focus-while-running.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/FocusSessionSupportTests.swift`
- `Tests/Shared/DayPlanPlannerStateTests.swift`

Given plan focus starts from tasks in `Plan to do today`
When focus time is allocated while running or after finish
Then task allocations are recorded without deleting the unassigned focus session history

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
