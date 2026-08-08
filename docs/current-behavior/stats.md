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
- [0436](../decisions/0436-remove-tracking-as-a-user-facing-task-type.md)
- [0470](../decisions/0470-keep-beta-experiments-out-of-production.md)
- [0503](../decisions/0503-remove-ios-secondary-stats-comparison-reports.md)

## Current Contract

- Stats dashboards are customizable, reorderable, and adaptive-width.
- iOS Stats renders dashboard reports lazily from reducer-owned presentation snapshots. Whole-history achievement and win derivations run only when the data snapshot changes, and semantic data-update bursts are coalesced before reloading.
- Compact Stats summary cards use widths that accommodate their icon, labels, value, and optional accessory; titles and captions wrap instead of truncating when additional vertical space is available.
- Stats offers Today, Week, Month, and Year presets plus an inclusive custom start/end date range on iOS and macOS. All dashboard reports and available integrations use the same selected boundaries.
- Single-day ranges, whether selected through Today or a one-day custom range, omit multi-day comparisons such as daily averages, best-day callouts, active-day badges, and trend charts.
- Dashboard reports appear only when their backing metric has data. Saved order and hidden-item preferences are preserved for when data appears later.
- Sleep time and Sleep sessions sit beside comparable summary reports when available and when the Away experiment is enabled.
- Goal reports follow the Goals beta setting.
- Place reports and place achievements follow the Places beta setting.
- macOS Event and Emotion reports follow the Mac Event/Emotion beta setting.
- iOS does not offer Focus vs completed work or Estimated vs Actual time reports. macOS keeps both reports addable but hidden by default.
- macOS Summary view and Edit toolbar controls are unavailable in production. Development builds can enable them through Support & About -> Beta Experiments -> `Show Stats dashboard controls`; saved dashboard customization state remains intact while the controls are hidden.
- macOS Stats and Adventure hide the shared Home toolbar search pill while keeping the top toolbar row, mode strip, and Stats/Adventure progress picker available.
- Wins, Achievements, Sleep scope, Goals UI, and Adventure surfaces remain implemented but are unavailable in production. Development builds can enable them through their related experiment settings; Sleep-specific Stats and Adventure surfaces also stay hidden while `Show Away` is off.
- Stats filter Query sections are unavailable in production. Development builds can enable them through Support & About -> Beta Experiments -> `Show filter query sections`; existing advanced query state remains compatible.
- Stats hero activity previews use range-appropriate buckets: day-level for week, roughly weekly for month, and trailing 12-month framing for year.
- Stats summary cards show assumed-done daily Gentle-routine counts and summed estimated time for eligible auto-assumed days in the selected range and active task filters. These assumed totals stay separate from recorded Done counts, charts, achievements, and completion history until the user confirms the assumed day.
- Stats task-type filtering offers only `All`, `Routines`, and `Todos`. Stats has no Tracking count, Tracking time, or Tracking dashboard item; internal record-shaped data is counted and filtered with routines.
- Adventure derives progression from existing activity history and shares the Mac Stats sidebar tab behind a `Stats / Adventure` segment when enabled.
