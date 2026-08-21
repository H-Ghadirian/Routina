# iOS Task Detail Priority Context Order

Area: Tasks / iOS Task Details

Decision links: [0586](../decisions/0586-group-ios-task-detail-priority-context-in-the-header.md), [0625](../decisions/0625-group-task-detail-add-detail-with-edit.md)

Current behavior: [Tasks](../current-behavior/tasks.md)

Coverage:

- `Tests/Shared/TaskDetailSharedViewSupportTests.swift`

Given a todo or routine exposes its saved priority-context fields in iOS Task Details
When the person scans the task header
Then Importance appears before Urgency
And Urgency appears before Pressure
And Thinking needed appears directly after Pressure
And Thinking needed is not placed in the separate primary-action card
And the controls adaptively wrap into compact rows when their labels fit
And accessibility Dynamic Type sizes stack the controls vertically
And every visible control has a semibold label, visible stroke, explicit accessibility value, and 44-point-high target

When one of these fields is hidden because it has no saved value
Then the header's `Add a detail` chooser continues to offer that field independently
