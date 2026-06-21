# 0264: Match Button Hit Areas to Visual Surfaces

## Status

Accepted

## Date

2026-06-21

## Refines

- [0024: Adopt Liquid Glass UI Surfaces](0024-adopt-liquid-glass-ui-surfaces.md)
- [0089: Prefer Native Apple Platform Patterns](0089-prefer-native-apple-platform-patterns.md)
- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)

## Context

Routina uses a mix of native button styles and custom plain SwiftUI buttons with glass cards, pills, rows, and chips. Plain buttons can accidentally leave only their text or icon tappable when the visual background is built from padding, glass effects, or overlays that do not define the interaction shape.

This makes controls feel broken: the UI visually promises a button-sized target, but only the label responds.

## Decision

Every visible button target must make its full visual surface interactive. For native SwiftUI controls, the native button style can own the hit area. For custom or plain buttons, the label or shared visual modifier must fill the intended target and define an explicit `contentShape` that matches the visible surface.

Shared Routina glass surfaces define their rounded interaction shape so glass-backed buttons inherit this behavior by default. New custom button surfaces should either reuse those shared modifiers or add an explicit shape at the same level as the visible button background.

## Consequences

- Users can tap or click anywhere inside the visible button, chip, card, row, or pill surface.
- Future custom buttons must not rely on text/icon-only SwiftUI hit testing.
- Non-button decorative surfaces can still use glass styling; the interaction shape matters when a button or gesture uses the surface as its visual target.
