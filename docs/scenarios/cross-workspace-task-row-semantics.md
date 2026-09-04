# Cross-Workspace Task-Row Semantics

Area: Tasks / Main Task List / Backlog / Task Ladder / iOS / macOS
Decision links: [0734](../decisions/0734-share-task-row-semantics-without-flattening-workspace-context.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/BacklogTaskRowPresentationTests.swift`
- `Tests/Shared/TaskRankingRowPresentationTests.swift`
- `Tests/Shared/IOSHomeWorkspaceNavigationSourceTests.swift`

Given the same active task can be presented in Backlog and Task Ladder
When each feature rebuilds its cached row snapshot
Then both use the same normalized title, emoji, task type, lifecycle status,
schedule, progress, next-step, Tag, Flag, and semantic tone values
And their scrolling row builders do not derive those values again

Given a Backlog task has an unresolved confirmed prerequisite
And its stored one-time state is Ready or In Progress
When Backlog rebuilds from tasks and completion history
Then the cached row reports Blocked
And completing the prerequisite allows the prior stored state to appear again

Given a person opens Backlog on iPhone
When task rows appear
Then each row emphasizes its Backlog path, due or schedule context, and next step
And it uses the shared task identity and status presentation

Given a person opens Task Ladder on iPhone
When ranked rows appear
Then each row keeps its rank section, Tags, temporal context, and child count
And container groups, task groups, and ordinary tasks remain visually distinct
And the task's shared identity and status presentation is unchanged

Given a person changes a Mac Backlog or Task Ladder Appearance preference
When a semantic field is hidden or shown
Then only that workspace's row density changes
And filtering, sorting, task placement, and the meaning of the field remain unchanged
