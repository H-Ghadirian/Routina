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

## Current Contract

- Stats dashboards are customizable, reorderable, and adaptive-width.
- Dashboard reports appear only when their backing metric has data. Saved order and hidden-item preferences are preserved for when data appears later.
- Sleep time and Sleep sessions sit beside comparable summary reports when available and when the Away experiment is enabled.
- Goal reports follow the Goals beta setting.
- Place reports and place achievements follow the Places beta setting.
- macOS Event and Emotion reports follow the Mac Event/Emotion beta setting.
- macOS Focus vs completed work and Estimated vs Actual time reports remain addable but start hidden by default.
- macOS Summary view and Edit toolbar controls are hidden by default behind Support & About -> Beta Experiments -> `Show Stats dashboard controls`; saved dashboard customization state remains intact while the controls are hidden.
- Wins, Achievements, Sleep scope, Goals UI, and Adventure surfaces remain implemented but are hidden by default behind their related settings; Sleep-specific Stats and Adventure surfaces also stay hidden while `Show Away` is off.
- Stats filter Query sections are hidden by default behind Support & About -> Beta Experiments -> `Show filter query sections`; existing advanced query state remains compatible and still appears in active filter summaries when nonempty.
- Stats hero activity previews use range-appropriate buckets: day-level for week, roughly weekly for month, and trailing 12-month framing for year.
- Adventure derives progression from existing activity history and shares the Mac Stats sidebar tab behind a `Stats / Adventure` segment when enabled.
