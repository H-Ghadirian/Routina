# 0638: Stabilize Mac Settings Section Disclosure Animation

## Status

Accepted

## Date

2026-08-23

## Refines

- [0450: Use Progressive Custom Section Management](0450-use-progressive-custom-section-management.md)
- [0635: Separate Mac Settings Section Surfaces](0635-separate-mac-settings-section-surfaces.md)

## Context

Mac Settings -> Sections uses one compact card per custom super section and
expands one editor at a time. The editor was inserted with a combined opacity
and move-from-top transition while the card also animated its layout height.
During the same frame, controls could appear outside the card and fade through
intermediate positions, making the disclosure feel unstable.

## Decision

Section disclosure uses an identity transition for the editor content and
animates the card's layout height only. The card clips its rounded bounds so
controls cannot paint outside the surface while the layout settles. The
header's chevron and the card tint may continue to animate with the disclosure
state, but editor controls do not fade or translate independently.

## Consequences

- Expanding and collapsing keeps the editor visually attached to its card.
- The one-editor-at-a-time progressive workflow remains unchanged.
- The transition is easier to reason about because insertion/removal and layout
  movement are not competing animations.
