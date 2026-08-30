## iOS Primary Tabs And New Actions Stay Stable

Area: UI / Tasks / Focus / Stats / Settings / Timeline
Decision links: [0695](../decisions/0695-promote-stats-and-settings-in-ios-navigation.md)
Current behavior: [UI](../current-behavior/ui.md), [Stats](../current-behavior/stats.md), [Settings](../current-behavior/settings.md)
Coverage:
- `Tests/Shared/IOSNewTabActionAvailabilityTests.swift`
- `Tests/Shared/IOSHomeWorkspaceNavigationSourceTests.swift`
- `Tests/Shared/IOSMoreTaskReviewNavigationTests.swift`
- `Tests/iOSUI/RoutinaUIPerformanceTests.swift`

Given Routina opens on compact or regular-width iOS
When the primary tab bar is presented
Then its standard destinations are Home, Search, New, Stats, and Settings in that order
And Timeline and More do not occupy tab-bar items

Given the person taps New from any primary tab
Then the chooser presents exactly Create Task first and Focus second
And Create Task opens the existing Smart Add flow
And Focus loads eligible active tasks and tags only after the person chooses it

Given no Focus or sprint timer is active
When the person chooses Focus
Then one picker offers task or tag attribution plus count-up and fixed-duration choices

Given a task, tag, unassigned, or sprint timer is already active
When the person chooses Focus
Then Routina opens that timer's controls instead of starting a conflicting timer

Given the person needs Timeline
When they select Timeline from the final Home workspace rows
Then Timeline opens inside Home's navigation hierarchy
And Back returns from a task's details to Timeline before returning to Home

Given legacy temporary state or a deep link requests Timeline or More
Then Timeline uses its non-tab fallback route
And More resolves to the direct Settings destination
