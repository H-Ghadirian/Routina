## Planner header keeps only actionable range choices

Area: Planner / macOS Header
Decision links: [0609](../decisions/0609-keep-planner-range-choices-actionable-in-compact-headers.md), [0303](../decisions/0303-align-mac-planner-range-picker-with-adaptive-days.md)
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

Given the regular Planner header row would leave less than 120 points of spare width, the Calendar header is below its comfortable expanded-control width for the controls currently visible, or the calendar has constrained its supported ranges
When the header renders
Then Planner view, Calendar task view, and Planner range each show only their current choice in a native menu
And opening a menu reveals its available options
And Go to date shows only its calendar icon while retaining its accessible date or range value

Given Week was preferred before the window narrowed
When the window becomes wide enough for Week again
Then Week returns to the available choices and becomes the effective range without rewriting Planner data

Given Week is active and no internal Planner sidebar is open
When the person opens the external Filters pane directly
Then the header and effective range immediately adapt to the remaining Planner width
And the result is the same as opening `Go to date` before Filters
