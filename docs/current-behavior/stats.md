# Stats Current Behavior

This page summarizes active Stats, reports, Achievements, Wins, Sleep, and Adventure behavior.

## Key Decisions

- [0112](../decisions/0112-show-estimated-actual-time-stats.md)
- [0113](../decisions/0113-allow-stats-dashboard-reordering.md)
- [0145](../decisions/0145-separate-recent-wins-from-achievements.md)
- [0149](../decisions/0149-use-rolling-achievement-period-windows.md)
- [0150](../decisions/0150-add-mac-adventure-progression-mvp.md)
- [0151](../decisions/0151-combine-mac-stats-and-adventure-tab.md)
- [0193](../decisions/0193-clarify-stats-activity-rhythm-preview.md)
- [0212](../decisions/0212-hide-goals-tab-by-default.md)
- [0213](../decisions/0213-hide-goals-ui-by-default-on-macos.md)
- [0214](../decisions/0214-re-enable-adventure-map-behind-beta-toggle.md)
- [0219](../decisions/0219-hide-stats-wins-behind-beta-toggle.md)
- [0221](../decisions/0221-hide-stats-sleep-tab-behind-beta-toggle.md)
- [0224](../decisions/0224-hide-stats-achievements-behind-beta-toggle.md)
- [0227](../decisions/0227-gate-stats-goal-event-reports.md)
- [0228](../decisions/0228-place-sleep-stats-with-summary-reports.md)
- [0229](../decisions/0229-hide-secondary-mac-stats-charts-by-default.md)
- [0236](../decisions/0236-hide-empty-stats-reports.md)
- [0275](../decisions/0275-hide-places-behind-beta-toggle.md)
- [0279](../decisions/0279-hide-sleep-stats-and-blocking-with-away-toggle.md)
- [0284](../decisions/0284-hide-filter-query-sections-behind-beta-toggle.md)
- [0324](../decisions/0324-hide-mac-stats-dashboard-controls-behind-beta-toggle.md)
- [0359](../decisions/0359-show-assumed-done-stats-summary.md)
- [0390](../decisions/0390-hide-mac-toolbar-search-on-stats-and-add-task.md)
- [0415](../decisions/0415-support-custom-stats-date-ranges.md)
- [0428](../decisions/0428-compose-tracking-behaviors-on-gentle-routines.md)
- [0642](../decisions/0642-unify-task-configuration-and-retire-legacy-task-kind-storage.md)
- [0470](../decisions/0470-keep-beta-experiments-out-of-production.md)
- [0503](../decisions/0503-remove-ios-secondary-stats-comparison-reports.md)
- [0504](../decisions/0504-simplify-ios-focus-2048-stats-details.md)
- [0505](../decisions/0505-use-dense-ios-stats-metric-tiles.md)
- [0549](../decisions/0549-filter-stats-by-task-flags.md)
- [0697](../decisions/0697-omit-apple-health-from-the-first-release.md)
- [0658](../decisions/0658-defer-mac-stats-tag-catalog-to-searchable-pickers.md)
- [0669](../decisions/0669-use-inline-menu-pickers-for-mac-stats-single-choice-filters.md)
- [0668](../decisions/0668-separate-general-stats-and-standardize-task-type-language.md)
- [0688](../decisions/0688-align-mac-stats-tag-and-flag-filters-with-shared-panels.md)
- [0689](../decisions/0689-open-mac-stats-evidence-from-task-backed-rectangles.md)
- [0691](../decisions/0691-split-focus-activity-across-local-days.md)
- [0695](../decisions/0695-promote-stats-and-settings-in-ios-navigation.md)
- [0706](../decisions/0706-gate-disabled-emotions-at-release-presentation-boundaries.md)

## Current Contract

- Stats is a direct iOS primary tab on compact and regular layouts; it is not nested under More.
- Stats dashboards are customizable, reorderable, and adaptive-width.
- Stats counts exact synchronized copies of one focus session once wherever that session type contributes: task, tag, and unassigned focus are canonicalized for duration, hourly rhythm, goal focus, Focus 2048, and task-focus achievements, while board focus is canonicalized for the duration and hourly evidence that includes it. Canonicalization changes derived evidence without deleting persisted history.
- Date-range Focus duration and hourly rhythm count actual active intervals rather than a session's Finish timestamp. Pause/Resume history removes paused gaps, each interval is split at local midnight, and only the portion inside the selected day or range contributes. A continuous 23:00-03:00 Focus contributes one hour to the first day and three hours to the second; pressing Finish today on a session paused yesterday contributes nothing to today. Legacy records without exact Pause/Resume history preserve their known active-duration total from the recorded start because the original gap placement cannot be recovered.
- Focus distribution charts fill their available viewport before using horizontal overflow for detailed long ranges. Cumulative Focus always fits the complete selected period into one viewport, marks its latest value, and does not require horizontal scrolling to reveal a nonzero ending trend. Both day axes sample the selected range to a compact set of complete labels, retain the first and last date, and add month context at the start of a custom range or when its visible labels cross a month boundary.
- The 24-hour rhythm keeps its three supporting facts readable on compact layouts: Period occupies one full-width row, while the selected metric total and Strongest hour use two value columns inside one summary panel instead of three equal pills.
- iOS Stats renders dashboard reports lazily from reducer-owned presentation snapshots. Whole-history achievement and win derivations run only when the data snapshot changes, and semantic data-update bursts are coalesced before reloading.
- iOS Cards mode uses dense two-column metric tiles, with compact icon/title headers and single-line values and captions. The separate Compact mode remains a shorter one-column summary row; macOS retains its larger cards. Both modes preserve the same values, captions, colors, and accessories.
- Stats offers Today, Week, Month, and Year presets plus an inclusive custom start/end date range on iOS and macOS. Date-range reports and available date-bound integrations use the same selected boundaries.
- Stats separates `General Stats` from `Date Range Stats`. Current Repeating-task, open One-time-task, active-item, archived-item, and goal totals sit in General Stats and do not change when only the date range changes; task filters still apply. Selected-period outcomes and activity sit in Date Range Stats, including `Done`, `Canceled`, and `Missed`.
- On macOS, clicking anywhere on a task-backed Stats rectangle opens an anchored evidence popover; Return and Space do the same when the rectangle has keyboard focus. This includes the activity overview; Daily average and Best day; Focus time and Focus per day; Done, Canceled, Missed, Assumed done, and Assumed time; and Repeating-task, open One-time-task, Active-item, and Archived-item summaries. Non-task-backed rectangles remain informational only.
- Evidence popovers use the same active task-type, matrix, query, Tag, Flag, and inclusive date filters as their source rectangle. Recorded and assumed outcomes group repeated occurrences under one task row with an explicit multiplier. Assumed time lists positive estimated-time contributors, while Focus lists aggregated task and non-task focus sources so the shown duration remains explainable. General inventory lists use current task state; Best day narrows its evidence to the displayed peak date. These lists are informational and do not mutate or navigate to tasks.
- Stats refreshes cache the matching task IDs beside the metrics. The Mac evidence resolver runs only after a deliberate rectangle action and its anchored popover uses a lazy bounded list, so no additional whole-history derivation enters the scrolling dashboard render path.
- Single-day ranges, whether selected through Today or a one-day custom range, omit multi-day comparisons such as daily averages, best-day callouts, active-day badges, trend charts, and the `Tasks created per day` chart.
- Dashboard reports appear only when their backing metric has data. Saved order and hidden-item preferences are preserved for when data appears later.
- When the dashboard has no reports and no active filters, its guidance names Sleep only while both the Away parent experiment and the Sleep experiment are enabled. With Sleep unavailable, the empty state mentions tasks, Focus, and other logged activity without advertising Sleep. Filtered empty states keep their range-and-filter recovery guidance instead.
- iOS Stats omits toolbar controls that cannot affect the current presentation. Cards/Compact requires a visible summary item; Edit requires at least one reportable dashboard item, including a hidden one that can be restored; and Filter requires task data or an active sheet filter that can be cleared. A non-default date range alone does not keep Filter visible because the range selector remains directly available. If reportable items disappear during editing, Stats exits edit mode and dismisses Add.
- Sleep time and Sleep sessions sit beside comparable summary reports when available and when the Away experiment is enabled.
- Goal reports follow the Goals beta setting.
- Place reports and place achievements follow the Places beta setting.
- Emotion summaries, trends, and achievement presentation follow the Event/Emotion beta setting on iOS and macOS. When that feature is unavailable, persisted Emotion history remains stored but does not produce a Stats section or achievement domain. Mac Event reports follow the same setting.
- iOS does not offer Focus vs completed work or Estimated vs Actual time reports. macOS keeps both reports addable but hidden by default.
- iOS Focus 2048 shows earned and next tiles with next-tile progress, without a largest-tile callout, tile-count label, or supplemental insight pills. macOS keeps those supplementary details.
- macOS Summary view and Edit toolbar controls are unavailable in production. Development builds can enable them through Support & About -> Beta Experiments -> `Show Stats dashboard controls`; saved dashboard customization state remains intact while the controls are hidden.
- macOS Stats and Adventure hide the shared Home toolbar search pill while keeping the top toolbar row, mode strip, and Stats/Adventure progress picker available.
- Wins, Achievements, Sleep scope, Goals UI, and Adventure surfaces remain implemented but are unavailable in production. Development builds can enable them through their related experiment settings; Sleep-specific Stats and Adventure surfaces also stay hidden while `Show Away` is off.
- Stats filter Query sections are unavailable in production. Development builds can enable them through Support & About -> Beta Experiments -> `Show filter query sections`; existing advanced query state remains compatible.
- Stats filters can independently include or exclude task Flags with `All` / `Any` matching. Those choices recalculate task-bound activity totals, charts, task counts, assumed totals, tag usage, and associated focus sessions from the cached Stats snapshot; independent integrations and logs retain their own scope.
- The macOS Stats sidebar presents Flags first in an always-expanded titled orange panel and Tags second in an always-expanded titled teal panel, matching Planner Shared. Each panel has one full-width edit action that opens a combined searchable Include/Exclude popover. Active rules stay visible outside it as removable summaries, `All` / `Any` appears only for a multi-value side, and idle panels omit empty-state copy. Tags retain counts, colors, pinned selections, bounded related suggestions, and lazy Browse rows. Stats keeps its own persisted analytical filter state and matching semantics rather than sharing Planner's selections, and an active panel remains available if its current catalog is empty.
- The macOS Stats sidebar presents Scope, Show, Time Range, Importance, and Urgency as native menu-style pickers inline with their titles inside passive colored cards. Their current values remain visible without expansion state, segmented option surfaces, animation, or sidebar reflow. Time Range offers Today, Week, Month, Year, and Custom in the same menu; only Custom reveals inclusive From and Through date fields beneath its row. Query retains its existing complex interaction, while Tags and Flags use their focused combined popovers.
- Importance and Urgency remain separate minimum-threshold filters. Changing one preserves the other, while `All` clears only that axis and the existing combined matching and persistence remain unchanged.
- Stats hero activity previews use range-appropriate buckets: day-level for week, roughly weekly for month, and trailing 12-month framing for year.
- Stats summary cards show assumed-done daily Gentle-routine counts and summed estimated time for eligible auto-assumed days in the selected range and active task filters. These assumed totals stay separate from recorded Done counts, charts, achievements, and completion history until the user confirms the assumed day.
- Stats task-type filtering offers only `All`, `Repeating`, and `One-time`. The underlying filter raw values remain `Routines` and `Todos` for persisted-state compatibility, and no additional task-kind count, time card, filter, or dashboard item exists.
- The first iPhone release contains no Apple Health connection prompt, movement cards, HealthKit implementation, or HealthKit capability declarations. iPad support is deferred from this release.
- Adventure derives progression from existing activity history and shares the Mac Stats sidebar tab behind a `Stats / Adventure` segment when enabled.
