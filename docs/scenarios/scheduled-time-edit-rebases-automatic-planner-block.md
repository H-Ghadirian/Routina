## Scheduled time edits rebase automatic Planner blocks

Area: Tasks / Planner / Recurrence
Decision links: [0375](../decisions/0375-split-time-blocks-from-available-windows.md), [0418](../decisions/0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
Current behavior: [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/DayPlanPlannerStateTests.swift`

Given a task has an automatic timed Planner block at 11:15
And the task-detail companion pane is open
When the person edits the task's scheduled time to 10:45 and saves
Then the routine-update notification refreshes the visible Planner data immediately
And the block moves to 10:45 when it still matches the previous automatic placement

Given the person previously moved or resized that task's Planner block
When the person edits the task's scheduled time
Then the existing manual placement remains unchanged
