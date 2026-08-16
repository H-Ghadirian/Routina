# iOS Task Detail Priority Context Order

Area: Tasks / iOS Task Details

Decision links: [0586](../decisions/0586-group-ios-task-detail-priority-context-in-the-header.md)

Current behavior: [Tasks](../current-behavior/tasks.md)

Coverage:

- `Tests/Shared/TaskDetailSharedViewSupportTests.swift`

Given a todo or routine exposes its saved priority-context fields in iOS Task Details
When the person scans the task header
Then Importance appears before Urgency
And Urgency appears before Pressure
And Thinking needed appears directly after Pressure
And Thinking needed is not placed in the separate primary-action card

When one of these fields is hidden because it has no saved value
Then `Add more details` continues to offer that field independently
