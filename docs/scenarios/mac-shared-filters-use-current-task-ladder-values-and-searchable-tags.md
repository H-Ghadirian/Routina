# Mac Shared Filters Use Current Task Ladder Values and Searchable Tags

Area: Tasks / Timeline / Planner / macOS UI

Decision links: [0418](../decisions/0418-keep-whole-history-work-out-of-scrolling-render-paths.md), [0649](../decisions/0649-give-each-task-ladder-metric-an-independent-time-rule.md), [0656](../decisions/0656-make-mac-all-filters-task-ladder-complete-and-searchable.md), [0660](../decisions/0660-make-mac-planner-filters-explicit-composable-and-bounded.md)

Current behavior: [Tasks](../current-behavior/tasks.md), [UI](../current-behavior/ui.md)

Coverage:

- `Tests/Shared/HomeTaskListFilteringTests.swift`
- `Tests/Shared/HomeFilterEditorTests.swift`
- `Tests/Shared/TimelineLogicTests.swift`
- `Tests/Shared/HomeMacAllFiltersSourceTests.swift`
- `Tests/macOS/HomeFeatureTests.swift`
- `Tests/macOS/PerformanceRegressionTests.swift`

Given a repeating task has lower stored After-done values and higher current
Now values because of Changes over time
When the person sets minimum Importance, Urgency, or Pressure in Mac `Shared`
Then Task List, task-backed Timeline activity, and task-backed Planner Calendar
items match the current values
And changing one threshold preserves the other Task Ladder filters
And Pressure at or above the selected threshold matches
And Thinking needed remains exact
And Estimated time distinguishes All, Has Estimate, and No Estimate

Given standalone Timeline activity has no task-owned Task Ladder values
When any Task Ladder value filter is active
Then the standalone activity is excluded
But a tag-only filter does not exclude it merely for lacking Task Ladder values

Given the saved tag catalog is large
When the person opens the ordinary `Shared` Tags card
Then it shows `No tag filter` or only the active included and excluded chips
And `All` / `Any` appears only for a rule containing more than one tag
When the person chooses `Add tags…` or `Add tags to exclude…`
Then a searchable picker pins selected tags, shows bounded suggestions, and
keeps the remaining catalog in a lazy Browse list with counts

Given filters are active in one or more Mac Planner filter scopes
When the person opens the filter companion pane
Then the scope picker reads `Shared` / `Task List` / `Timeline` / `Calendar`
And each active scope has an indicator even when another scope is selected
And the selected scope explains which surface owns its controls

Given Timeline contains completed and missed routine and todo history
When the person chooses Type `Todos` and Status `Done`
Then both selections remain visible and persisted
And only completed todo history matches
And changing either selection preserves the other

Given the filter companion pane is expanded fullscreen on a wide Mac window
When the filter surface renders
Then its content is centered within an 840-point maximum
And minimizing returns the same state to the 420-point companion pane

Given Planner Calendar has an unchanged task snapshot and shared-filter state
When SwiftUI reevaluates the Calendar during scrolling or layout
Then shared task membership and task ID sets come from the cached snapshot
And current Task Ladder values are not rederived until data, filters, day, or
calendar semantics change
