# UI Current Behavior

This page summarizes app-wide UI interaction behavior. Decision records explain why these rules exist.

## Key Decisions

- [0024](../decisions/0024-adopt-liquid-glass-ui-surfaces.md)
- [0089](../decisions/0089-prefer-native-apple-platform-patterns.md)
- [0188](../decisions/0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0264](../decisions/0264-match-button-hit-areas-to-visual-surfaces.md)
- [0296](../decisions/0296-present-mac-task-details-as-planner-inspector.md)
- [0297](../decisions/0297-open-mac-task-rows-fullscreen-on-double-click.md)
- [0299](../decisions/0299-constrain-mac-home-window-size.md)
- [0302](../decisions/0302-minimize-fullscreen-mac-task-details-to-companion-pane.md)
- [0306](../decisions/0306-use-day-planner-width-for-task-detail-inspector-fit.md)
- [0312](../decisions/0312-move-mac-task-timeline-filter-entry-to-toolbar.md)
- [0315](../decisions/0315-merge-mac-quick-add-into-toolbar-search.md)

## Current Contract

- Visible button targets are interactive across their full visual surface, not only across their text, emoji, or icon.
- Native SwiftUI button styles may own their native hit areas.
- Custom or plain buttons must make the intended button surface fill the target and define a matching `contentShape`.
- Routina glass-backed cards, pills, and panels provide rounded hit shapes through their shared visual modifiers so new glass-backed buttons inherit the rule by default.
- Mac Home uses expanded regular toolbar chrome with an AppKit-backed search-or-create field in the centered principal slot. It uses the shared Home search text so task lists, Timeline-style lists, Planner List mode's full Timeline surface, and task-backed Planner Calendar items can be searched from the top of the window. The field placeholder names both search and task creation, and a compact `Return` / `Create task` hint appears when the current non-empty query has no matching task or timeline result. When that create-eligible query also contains quick-add syntax such as due words, recurrence, tags, places, priority, or duration, a flat same-width parser preview attaches under the toolbar field showing the cleaned task title and detected details without duplicating the `Return` / `Create task` hint. The configurable Mac Quick Add shortcut focuses this toolbar field. Pressing Return with a non-empty query creates a task through the shared Quick Add parser only when the query has no task or timeline result; otherwise the field remains a live search. Successful toolbar creation clears search and shows the created-task toast, subscription limits open the paywall, and creation errors use a Home alert. The toolbar command row holds compact Home controls such as filters, Focus, mode navigation, Add, and optional Progress controls. Its Home filter button opens Home-level filters in a right-side `Both` / `Task List` / `Timeline` companion pane; shared tag and importance/urgency filters live under `Both`, while Timeline has no range filter. Task and Timeline sidebars do not render duplicate search fields or filter icon buttons for that same toolbar area, though they may show active-filter summaries and clear actions. The toolbar field restores first responder after search updates so typing stays focused there, but it does not reclaim focus after the user moves into another text editor such as task comments or notes.
- On Mac, task detail presentation follows the active workspace. Mac Home opens at 1280 x 760 and cannot resize below 1200 x 720. When Planner is active, single-click task-list selection and Planner task selection open a right-side companion detail pane beside the calendar when the detail area can fit the fixed companion pane plus a Day-capable Planner surface. At tight widths, the Planner calendar can adapt down to a compact Day layout to make room for the pane. Task-detail and Home filter companion panes have close and fullscreen controls, and fullscreen views opened from those panes can minimize back to the previous pane layout. Those panes are mutually exclusive with each other, Planner's internal right sidebar, and the board inspector. Full Details close still returns to Planner and clears the task-detail pane. Double-clicking a Mac task-list row opens the full Details surface.
