## Calendar List dismisses the Day Tasks sidebar

Area: Planner / macOS Calendar
Decision links: [0369](../decisions/0369-show-day-task-list-columns-in-planner-calendar.md), [0724](../decisions/0724-keep-day-tasks-sidebar-out-of-calendar-list.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/DayPlanPlannerStateTests.swift`

Given Calendar `Schedule` has the focused Day Tasks sidebar open for a date
When the person switches the Calendar task view to `List`
Then the Day Tasks sidebar closes
And the per-day List columns remain visible without a duplicate focused-day pane

Given Calendar `List` is active
Then stale selected-day state cannot present the Day Tasks sidebar
And Day Tasks cannot be opened until the person returns to Schedule
And Filters, Go to date, and task-detail companions remain available

Given the person returns from List to Schedule
Then Day Tasks stays closed until a day-header task button is selected again
