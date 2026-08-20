## Mac Task Ladder Excludes Relationship-Blocked Tasks

Area: Tasks / Mac Task Ladder / Relationships
Decision links: [0562](../decisions/0562-exclude-blocked-tasks-from-mac-task-ladder.md), [0596](../decisions/0596-advance-repeating-blocked-by-chains-by-completion-order.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/TaskRankingPresentationTests.swift`

Given a task has an unresolved confirmed `Blocked by` relationship
And its stored Todo state is Ready or In Progress
When the Task Ladder cached presentation is rebuilt
Then the task does not appear in any metric section
And it does not contribute to the ladder count
And its stored Todo state remains unchanged

Given a repeating prerequisite has completed after the dependent task's latest completion
When the Task Ladder cached presentation is rebuilt
Then the dependent task is eligible again until its next completion consumes that handoff

The direct relationship-blocking and repeating completion-handoff cases are
covered by `TaskRankingPresentationTests`.
