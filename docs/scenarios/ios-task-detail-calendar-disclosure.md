# iOS Task Detail Calendar Disclosure

Area: Tasks / iOS Task Details

Decision links: [0585](../decisions/0585-persist-ios-task-detail-calendar-expansion-per-task.md)

Current behavior: [Tasks](../current-behavior/tasks.md)

Coverage:

- `Tests/iOS/TaskDetailFeatureTests.swift`
- `Tests/Shared/SwiftDataModelTests.swift`
- `Tests/Shared/TaskDetailSharedViewSupportTests.swift`
- `Tests/Shared/SettingsRoutineDataBackupMappingTests.swift`
- `Tests/Shared/SettingsRoutineDataPersistenceTests.swift`

Given a task has never stored an iOS Task Detail calendar preference
When the person opens its Task Details
Then Calendar is collapsed and its full disclosure header remains clickable and accessible

When the person expands Calendar and later returns to that task
Then its calendar is expanded
And another task remains collapsed until the person expands that task

When the person collapses the first task's calendar again
Then the collapsed choice is also restored on the next visit
And copying, synchronization, and backup/import preserve the task-owned choice
And macOS Task Details remains unchanged
