## Go to date remains clear when the Mac Planner header is tight

Area: Planner / macOS Header
Decision links: [0609](../decisions/0609-keep-planner-range-choices-actionable-in-compact-headers.md), [0606](../decisions/0606-show-icon-only-go-to-date-button-before-label-truncation.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/DayPlanPlannerStateTests.swift`
- `Tests/macOS/PerformanceRegressionTests.swift`

Given the macOS Planner header has enough room for the regular `Go to date` label
When the header is rendered
Then the selected date or range remains visible in the button

Given the regular Planner header row would leave less than its 120-point usability reserve or the Calendar header is below its comfortable expanded-control width
When the header is rendered
Then the `Go to date` button shows the calendar icon without an ellipsized date label
And the view, Calendar task-view, and range choices remain available as current-value menus
And its accessibility value and help still expose the selected date or range

Given loaded data makes the Planner Focus control visible in Mac Calendar
When the header is rendered
Then the `Go to date` button shows only its calendar icon
And the view, Calendar task-view, and range choices may remain expanded when the recovered room is sufficient
And its accessibility value and help still expose the selected date or range

Given the calendar can render only Day or 3 Days
When the header enters its compact state
Then Go to date remains icon-only
And the range menu omits every range that cannot take effect
