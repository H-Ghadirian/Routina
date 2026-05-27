# 0089: Prefer Native Apple Platform Patterns

- Status: Accepted
- Date: 2026-05-27

## Context

Routina is an Apple-platform app and already targets the current Apple SDK baseline. When the app recreates standard system behavior by hand, it risks losing expected platform details such as navigation transitions, accessibility behavior, gestures, focus, animation timing, toolbar semantics, keyboard behavior, and future compatibility with Apple platform updates.

Users expect iOS, macOS, and watchOS screens to behave like current Apple apps unless Routina has a clear product reason to do otherwise.

## Decision

Prefer native Apple platform solutions, Apple-recommended patterns, and current SDK APIs before building custom behavior from scratch. This applies to navigation, presentation, controls, gestures, animations, toolbars, lists, forms, accessibility, persistence integrations, and system surfaces.

When choosing an implementation, use this priority order:

1. Current native Apple API or system component that matches the product behavior.
2. Established SwiftUI, UIKit, AppKit, WidgetKit, ActivityKit, App Intents, or related Apple-framework pattern for the current platform baseline.
3. A narrow adapter around native behavior when Routina needs app-specific state, routing, styling, or cross-feature coordination.
4. Custom implementation only when native APIs cannot provide the required behavior, have a verified platform limitation, or would create a worse user experience for this app.

If custom behavior is necessary, keep it as small and reversible as possible, preserve native platform semantics where practical, and revisit it when a current Apple API becomes viable.

## Consequences

- Engineers should bias toward Apple-owned navigation and presentation transitions instead of hand-rolled animation or view swapping.
- Custom controls should not replace standard controls unless they provide meaningful Routina-specific behavior that the native control cannot express.
- Workarounds for platform bugs should be documented in code or a decision record when they affect product behavior, so they can be removed once a native solution is safe.
- New Apple APIs and updated platform guidance should be considered during feature work because Routina intentionally follows the latest verified Apple SDK baseline.
