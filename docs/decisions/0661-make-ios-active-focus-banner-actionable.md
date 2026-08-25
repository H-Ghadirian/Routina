# 0661: Make the iOS Active Focus Banner Actionable

## Status

Accepted

## Date

2026-08-25

## Refines

- [0123: Pause Focus Timers](0123-pause-focus-timers.md)
- [0127: Pause Board Focus Timers](0127-pause-board-focus-timers.md)
- [0264: Match Button Hit Areas to Visual Surfaces](0264-match-button-hit-areas-to-visual-surfaces.md)
- [0545: Bound iOS Foreground Focus Reconciliation](0545-bound-ios-foreground-focus-reconciliation.md)

## Context

iOS Home could show a Focus timer imported from another device, but the banner
did not provide a usable destination for tag or unassigned Focus. Sprint Focus
opened a read-only sprint summary. Even when a task route was available, the
banner did not clearly promise a consistent place to control the active timer.
This left a cross-device timer visible without a reliable way to pause or end it
from the iPhone.

## Decision

The full visible iOS Home Focus banner is one actionable surface and always opens
an active-Focus control sheet for task, tag, unassigned, and sprint timers. The
sheet shows the timer's attribution, live active-time status, and the shared
Pause/Resume, Finish, and Abandon actions. Task-backed Focus also offers a route
to the related Task Details.

Finish keeps the elapsed active time as completed Focus history. Abandon ends
the timer without keeping it as completed history. Sprint Focus uses these same
shared mutation semantics, including closing an active pause before Finish and
removing the active session on Abandon. Successful mutations save normally so
their terminal or pause state can synchronize back to the originating device.

If another device ends the session while the sheet is open, iOS reports that
the timer changed instead of applying an action to a different active session.

## Consequences

- Every active timer shown at the top of iOS Home has a useful tap destination.
- Cross-device Focus can be paused, resumed, finished, or abandoned from iPhone
  without first finding a task-specific screen.
- Finish and Abandon remain distinct rather than adding an ambiguous second
  `Stop` meaning.
- The banner's visual surface, accessibility label, hint, and chevron all
  communicate that it opens controls.
