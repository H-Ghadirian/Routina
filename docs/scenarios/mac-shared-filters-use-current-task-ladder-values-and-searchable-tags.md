# Mac Shared Filters Use Current Task Ladder Values and Searchable Tags

Area: Tasks / Timeline / Planner / macOS UI

Decision links: [0418](../decisions/0418-keep-whole-history-work-out-of-scrolling-render-paths.md), [0649](../decisions/0649-give-each-task-ladder-metric-an-independent-time-rule.md), [0656](../decisions/0656-make-mac-all-filters-task-ladder-complete-and-searchable.md), [0660](../decisions/0660-make-mac-planner-filters-explicit-composable-and-bounded.md), [0671](../decisions/0671-present-mac-shared-tags-as-direct-actions.md), [0673](../decisions/0673-use-compact-pickers-for-narrow-mac-filters.md)

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
When the person opens `Shared`
Then Tags has no disclosure card, section header, or empty-state copy
And direct tinted `Include tags` and `Exclude tags` actions remain visible
When an include or exclude rule has selected tags
Then its removable chips appear beneath the corresponding action
And `All` / `Any` appears only for a rule containing more than one tag
When the person chooses `Include tags` or `Exclude tags`
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
And Shared and Task List segmented choices that fit use one equal-width row
And Timeline's bounded Type, Status, and Media choices use the card width
And filter switches share a trailing alignment
And Task List, Timeline, and Calendar Appearance rows keep left-aligned labels,
one trailing switch column, and a full-row toggle target
And minimizing returns the same state to the 420-point companion pane

Given the same filter surface is shown in the 420-point companion pane
When a multi-option control cannot fit comfortably on one line
Then it uses one compact menu picker that preserves the current selection
And one-line choices remain directly segmented

Given Planner Calendar has an unchanged task snapshot and shared-filter state
When SwiftUI reevaluates the Calendar during scrolling or layout
Then shared task membership and task ID sets come from the cached snapshot
And current Task Ladder values are not rederived until data, filters, day, or
calendar semantics change
