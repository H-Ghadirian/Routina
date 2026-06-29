# 0313 Disable Mac App Widgets in App Targets

- Status: Accepted
- Date: 2026-06-29
- Refines: [0135 Show Today Focus Widget](0135-show-today-focus-widget.md) and [0210 Store Durable Preferences in SwiftData](0210-store-durable-preferences-in-swiftdata.md)

## Context

Routina's macOS widget bundle is useful for glanceable focus, stats, and contribution activity, but it is not ready to expose to users. Showing disabled placeholder widgets would still make Routina appear in the macOS widget gallery, which is not the intended release behavior.

## Decision

Mac app widgets remain in source and as standalone widget extension targets, but the Mac app targets do not build, embed, or register the widget extensions. This keeps the code available for later release work without exposing Routina widgets to users.

Mac-side widget payload refresh behavior is hard-disabled in code while the widget extension is not shipped. iOS widget and Live Activity behavior is not changed by this Mac release decision.

Re-enabling Mac widgets later requires an explicit project change to restore the app target dependency/embed/registration wiring and the Mac widget refresh gate.

## Consequences

- Routina does not appear as a macOS widget provider through the Mac app build.
- Widget implementation files stay in the repository for future release work.
- Users do not see disabled placeholder widgets.
- This behavior is code-controlled, not exposed as a Settings beta toggle.
