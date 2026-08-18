## When-Needed Repeating Task Pauses After Completion

Area: Tasks / Recurrence
Decision links: [0605](../decisions/0605-add-when-needed-repeating-routines.md), [0421](../decisions/0421-support-cadence-free-repeating-routines.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/SwiftDataModelTests.swift`
- `Tests/Shared/RoutineLogHistoryTests.swift`
- `Tests/Shared/RoutineRecurrenceDraftTests.swift`

Given a repeating routine is configured as `When needed`
When the person completes it
Then the completion is preserved in history
And the task enters the existing indefinite paused/archived lifecycle
And the task is not shown in active projections

When the person resumes the task
Then it becomes active again
And it remains configured as `When needed`
And its next completion pauses it again

When the person undoes the latest completion
Then the automatic pause created by that completion is removed
And the task remains configured as `When needed`

Given a repeating routine is configured as `No schedule`
When the person completes it
Then it remains active and available immediately
