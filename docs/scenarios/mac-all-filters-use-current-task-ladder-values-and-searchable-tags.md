# Mac All Filters Use Current Task Ladder Values and Searchable Tags

Area: Tasks / Timeline / Planner / macOS UI

Decision links: [0364](../decisions/0364-rename-shared-mac-filter-scope-to-all.md), [0418](../decisions/0418-keep-whole-history-work-out-of-scrolling-render-paths.md), [0649](../decisions/0649-give-each-task-ladder-metric-an-independent-time-rule.md), [0656](../decisions/0656-make-mac-all-filters-task-ladder-complete-and-searchable.md)

Current behavior: [Tasks](../current-behavior/tasks.md), [UI](../current-behavior/ui.md)

Coverage:

- `Tests/Shared/HomeTaskListFilteringTests.swift`
- `Tests/Shared/HomeFilterEditorTests.swift`
- `Tests/Shared/TimelineLogicTests.swift`
- `Tests/Shared/HomeMacAllFiltersSourceTests.swift`

Given a repeating task has lower stored After-done values and higher current
Now values because of Changes over time
When the person sets minimum Importance, Urgency, or Pressure in Mac `All`
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
When the person opens the ordinary `All` Tags card
Then it shows `No tag filter` or only the active included and excluded chips
And `All` / `Any` appears only for a rule containing more than one tag
When the person chooses `Add tags…` or `Add tags to exclude…`
Then a searchable picker pins selected tags, shows bounded suggestions, and
keeps the remaining catalog in a lazy Browse list with counts
