# Task Detail locks time-varying Task Ladder values

## Configured Changes over time stays read-only in Task Details

Area: Tasks / iOS and macOS Task Details
Decision links: [0648](../decisions/0648-keep-time-varying-task-ladder-values-read-only-in-details.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskDetailSharedViewSupportTests.swift`
- `Tests/Shared/TaskDetailMacHeaderControlLayoutTests.swift`
- `Tests/Shared/TaskDetailTodoStateTests.swift`

Given a repeating task has a configured Changes over time rule
When the person opens Task Details
Then Importance, Urgency, Pressure, and Thinking needed are read-only
And Importance, Urgency, and Pressure are identified as After done values
And the summary explains the derived Now values, targets, and due-date timing
And Task Details directs configuration through Edit Task without presenting a
separate Changes over time editor

When a stale Task Detail value action is sent while the rule exists
Then the stored After done values and Thinking needed remain unchanged

Given a task has no Changes over time rule
When the person opens Task Details
Then its four Task Ladder values retain their direct editing controls
