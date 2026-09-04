# iOS Workspace Controls

Area: Tasks / Backlog / Task Ladder / iOS
Decision links: [0736](../decisions/0736-give-ios-workspaces-scope-aware-controls.md)
Current behavior: [Tasks](../current-behavior/tasks.md)
Coverage:
- `Tests/Shared/IOSHomeWorkspaceNavigationSourceTests.swift`
- `Tests/Shared/BacklogTaskListPresentationTests.swift`
- `Tests/Shared/TaskRankingWorkspaceControlStateTests.swift`

Given a person opens Backlog on iPhone
When they open the workspace-control toolbar action
Then a native sheet separates Filter from Sort
And Filter exposes the existing Backlog task, date, Task Ladder value, estimate,
media, Tag, and iOS-visible Flag rules
And Sort offers Default, Due Soonest, and Due Latest without changing hierarchy
And Search and Refresh remain direct workspace actions

Given Backlog has non-default filters and a non-default sort
When the person resets Filter
Then Sort remains unchanged
When the person resets Sort
Then Filter remains unchanged
And customized state is visible from the toolbar and the relevant sheet tab

Given a person opens Task Ladder on iPhone
When the ranked list appears
Then metric, Base or Now values, and order do not occupy a permanent first section
And the same workspace-control toolbar action opens separate View and Sort tabs
And prior-ladder navigation remains in the list when structurally required

Given a person changes Task Ladder View and Sort
When they reset the selected tab
Then View returns to Pressure and Base without changing remembered direction
Or Sort restores the default directions without changing View

Given the person uses iPhone rather than Mac
When they open Backlog or Task Ladder controls
Then no Mac row Appearance tab is shown
And task meaning, filter meaning, sort meaning, and vocabulary remain consistent
without forcing the Mac density configuration onto the compact phone rows
