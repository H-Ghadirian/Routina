# Planner Search Reveals Backlog Tasks

Area: Tasks / Planner / Backlog / macOS
Decision links: [0687](../decisions/0687-reveal-backlog-tasks-in-explicit-planner-search.md)
Current behavior: [Tasks](../current-behavior/tasks.md), [Planner](../current-behavior/planner.md)
Coverage:
- `Tests/Shared/HomeTaskListFilteringTests.swift`

Given an active task is explicitly assigned to a Backlog super section or subsection
And it may also carry `Hide from Task Lists`
When no Planner search is active
Then the task remains absent from ordinary Planner sidebar placement
And explicit Backlog placement does not leak it into `Hidden by flag`

When the person searches Planner for text matching that task
Then the task appears once under `Search Results`
And the row names its location as `Backlog › <section path>`
And the row can open Task Details without moving the task or offering inline completion

When the person clears search
Then the task disappears from the Planner sidebar again
And its Backlog assignment is unchanged
