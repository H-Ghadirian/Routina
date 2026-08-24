## Planner header keeps only actionable range choices

Area: Planner / macOS Header
Decision links: [0609](../decisions/0609-keep-planner-range-choices-actionable-in-compact-headers.md), [0303](../decisions/0303-align-mac-planner-range-picker-with-adaptive-days.md), [0654](../decisions/0654-progressively-reveal-mac-planner-header-choices.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/DayPlanPlannerStateTests.swift`
- `Tests/macOS/PerformanceRegressionTests.swift`

Given the Mac Planner calendar has enough width for seven readable day columns
When the person opens the range control
Then Day, 3 Days, and Week are available
And selecting Week renders seven columns

Given the calendar has enough width for three readable columns but not seven
When the person opens the range control
Then Day and 3 Days are available
And Week is absent instead of accepting a selection that cannot take effect

Given the Mac Planner header renders
Then Planner view, Calendar task view, and Planner range each show only their current value in a compact full-surface trigger
When the person opens one trigger
Then only that control reveals its complete segmented choices in place
And its leading position stays fixed while later controls move right
And opening another control collapses the first
And choosing any option collapses the expanded control

Given Reduce Motion is enabled
When a Planner header choice expands or collapses
Then the same one-at-a-time state change occurs without the horizontal transition

Given the widest one-expanded Planner header row would leave less than 120 points of spare width or the Calendar header is below its comfortable labeled-date width
When the header renders
Then Go to date shows only its calendar icon while retaining its accessible date or range value
And the three progressive choice controls keep the same interaction

Given Week was preferred before the window narrowed
When the window becomes wide enough for Week again
Then Week returns to the available choices and becomes the effective range without rewriting Planner data

Given Week is active and no internal Planner sidebar is open
When the person opens the external Filters pane directly
Then the header and effective range immediately adapt to the remaining Planner width
And the result is the same as opening `Go to date` before Filters
