# 0595: Keep Task Completion Colors Consistent Across Platforms

## Status

Accepted

## Date

2026-08-16

## Refines

- [0089: Prefer Native Apple Platform Patterns](0089-prefer-native-apple-platform-patterns.md)
- [0507: Clarify iOS Task Detail Action Hierarchy](0507-clarify-ios-task-detail-action-hierarchy.md)
- [0521: Group Secondary Mac Task Detail Actions](0521-group-secondary-mac-task-detail-actions.md)
- [0594: Simplify iOS Task Detail Scan and Action Hierarchy](0594-simplify-ios-task-detail-scan-and-action-hierarchy.md)

## Context

Task Details used the same prominent completion concept on iOS and macOS, but the
platforms communicated it with different colors. macOS used green for creating a
completion and orange for undoing one or stopping ongoing work, while iOS inherited
the app accent color for its primary button. The inconsistent tint weakened a useful
semantic cue and made the same action feel unrelated across devices.

## Decision

Task Detail primary lifecycle actions share one semantic tint rule across iOS and
macOS while retaining each platform's native control shape and placement:

- actions that create or log a completion use green;
- actions that undo a completion or stop an ongoing multi-day routine use orange;
- iOS `Log another completion` remains green because it records another positive
  completion rather than reversing the existing one; and
- both platforms obtain these colors from shared Task Detail presentation logic.

Semantic color consistency is a cross-platform product rule, not a requirement for
pixel-identical layouts. Native interaction patterns remain platform-specific.

## Consequences

- Green consistently communicates successful completion on iPhone, iPad, and Mac.
- Orange distinguishes reversal or stopping from recording completed work.
- Future Task Detail completion controls cannot silently drift to unrelated accent
  colors on one platform.
- Accessibility continues to rely on labels, icons, and control state as well as
  color.
