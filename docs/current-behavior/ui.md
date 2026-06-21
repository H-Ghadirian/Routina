# UI Current Behavior

This page summarizes app-wide UI interaction behavior. Decision records explain why these rules exist.

## Key Decisions

- [0024](../decisions/0024-adopt-liquid-glass-ui-surfaces.md)
- [0089](../decisions/0089-prefer-native-apple-platform-patterns.md)
- [0188](../decisions/0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0264](../decisions/0264-match-button-hit-areas-to-visual-surfaces.md)

## Current Contract

- Visible button targets are interactive across their full visual surface, not only across their text, emoji, or icon.
- Native SwiftUI button styles may own their native hit areas.
- Custom or plain buttons must make the intended button surface fill the target and define a matching `contentShape`.
- Routina glass-backed cards, pills, and panels provide rounded hit shapes through their shared visual modifiers so new glass-backed buttons inherit the rule by default.
