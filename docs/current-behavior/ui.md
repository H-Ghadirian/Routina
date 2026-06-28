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

## Current Contract

- Visible button targets are interactive across their full visual surface, not only across their text, emoji, or icon.
- Native SwiftUI button styles may own their native hit areas.
- Custom or plain buttons must make the intended button surface fill the target and define a matching `contentShape`.
- Routina glass-backed cards, pills, and panels provide rounded hit shapes through their shared visual modifiers so new glass-backed buttons inherit the rule by default.
- On Mac, task detail presentation follows the active workspace. Mac Home opens at 1280 x 760 and cannot resize below 1200 x 720. When Planner is active, single-click task-list selection and Planner task selection open a right-side companion detail pane beside the calendar when the detail area can fit the fixed companion pane plus a Day-capable Planner surface. At tight widths, the Planner calendar can adapt down to a compact Day layout to make room for the pane. The companion pane has close and fullscreen controls, and it is mutually exclusive with Planner's internal right sidebar. Full Details opened from that fullscreen control has a minimize/return control that restores the companion pane; its close control still returns to Planner and clears the pane. Double-clicking a Mac task-list row opens the full Details surface.
