# Backlog Due-Date Sort

Area: Tasks / Backlog / macOS
Decision links: [0716](../decisions/0716-sort-mac-backlog-by-due-date.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/BacklogTaskListPresentationTests.swift`
- `Tests/macOS/BacklogFeatureTests.swift`
- `Tests/Shared/MacWorkspaceNavigationSourceTests.swift`

Given one Backlog group contains one-time tasks with deadlines, a repeating Due routine, and a task with no due boundary
When the person chooses Due Soonest
Then rows with true due boundaries appear from earliest to latest
And the undated task remains last

When the person chooses Due Latest
Then rows with true due boundaries appear from latest to earliest
And the undated task remains last

Given a later-due task is pinned
When Due Soonest is selected
Then an earlier due task still appears first because the explicit due sort is primary

Given empty Backlog destinations exist
When a due sort is selected without any filter
Then those empty super sections and subsections remain visible
And the toolbar indicates that Backlog has a non-default presentation choice

When the person uses Reset
Then Backlog restores both its default order and its default filters
