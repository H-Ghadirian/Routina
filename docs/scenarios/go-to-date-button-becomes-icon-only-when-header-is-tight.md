## Go to date remains clear when the Mac Planner header is tight

Area: Planner / macOS Header
Decision links: [0606](../decisions/0606-show-icon-only-go-to-date-button-before-label-truncation.md), [0320](../decisions/0320-hide-planner-range-picker-in-tight-inspector-layouts.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/DayPlanPlannerStateTests.swift`
- `Tests/macOS/PerformanceRegressionTests.swift`

Given the macOS Planner header has enough room for the regular `Go to date` label
When the header is rendered
Then the selected date or range remains visible in the button

Given Day / 3 Days / Week still fits when Go to date uses only its calendar icon
And the same active full row would overflow with the intrinsic date/range label
When the header is rendered
Then the `Go to date` button shows the calendar icon without an ellipsized date label
And the range picker remains visible
And its accessibility value and help still expose the selected date or range

Given even the full row with the compact date icon cannot fit
When the header hides the range picker
Then it recomputes the date-label fit against the collapsed row
