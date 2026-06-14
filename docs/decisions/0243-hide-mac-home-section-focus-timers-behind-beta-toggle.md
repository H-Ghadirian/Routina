# 0243: Hide Mac Home Section Focus Timers Behind Beta Toggle

## Status

Accepted

## Date

2026-06-14

## Context

Mac Home sidebar section and group headers offered a context menu for starting unassigned focus timers. This made tag section titles unexpectedly actionable from right-click, especially in the default first Home sidebar tab where section headers otherwise read like navigation and organization labels.

## Decision

Mac Home hides section and group header Focus Timer context-menu actions by default. Users can opt back in from Settings -> General -> Beta Experiments with `appSettingMacHomeSectionFocusTimersEnabled`.

Task-level focus actions and toolbar focus controls remain available separately.

## Consequences

- Right-clicking tag section titles no longer exposes a timer-start action in the default Mac Home sidebar.
- Users who intentionally want header-level unassigned focus shortcuts can restore them explicitly.
- The setting remains a local beta `UserDefaults` flag and does not require a SwiftData migration.
