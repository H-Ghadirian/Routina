## Planner Focus resize updates the owning session

Area: Focus / Planner / Task Details / macOS
Decision links: [0600](../decisions/0600-edit-recorded-tag-focus-from-mac-planner.md), [0651](../decisions/0651-keep-task-focus-separate-from-actual-time.md), [0715](../decisions/0715-update-recorded-focus-at-its-source-when-resizing-planner-evidence.md), [0720](../decisions/0720-persist-focus-resize-progress-before-gesture-finalization.md)
Current behavior: [Planner](../current-behavior/planner.md), [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/DayPlanPlannerStateTests.swift`

Given Mac Calendar `Schedule` shows a completed task-Focus rectangle
And Task Details reports the owning task's accumulated Focus time
When the person resizes that rectangle and releases the grip
Then the owning Focus session adopts the resized start and duration
And Task Details immediately recalculates its Focus total from that session
And Actual time remains unchanged

Given Planner's cached data has not loaded the owning Focus session
Or older exact Focus evidence retains the session's segment-start timestamp but no longer its canonical block ID
When the person resizes the completed Focus rectangle
Then Planner resolves one unambiguous owner from persistent Focus history
And every accepted resize saves the session together with the visible block
And a missing final gesture callback cannot leave the session at its old duration

Given the person switches from Planner to Backlog after that resize
When they return to Planner, reopen Routina, or Focus reconciliation runs
Then the resized Calendar rectangle remains unchanged
And Undo or Redo restores the Focus session and every affected Calendar day together
