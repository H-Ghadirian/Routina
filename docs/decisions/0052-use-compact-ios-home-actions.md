# 0052: Use Compact iOS Home Icon Actions

## Status

Superseded

## Date

2026-05-25

Superseded by [0055](0055-move-ios-home-place-and-sleep-into-action-rail.md).

Supersedes the iPhone bottom-dock expectation in [0039](0039-move-mac-check-in-to-home-toolbar.md) and updates the iOS Home sleep dock presentation from [0012](0012-model-sleep-as-app-level-session-mode.md).

## Context

iOS Home previously embedded large bottom controls at the end of the task list. The shared place check-in dock exposed map, activity, end, and suggested-place controls before the user had asked for the check-in flow. The sleep dock exposed a title, subtitle, icon, and arrow even though its primary job is a single start-sleep action.

The existing map check-in sheet already owns the detailed current-location, saved-place, activity, history, and edit flows.

## Decision

iOS Home exposes place check-in and sleep as compact trailing icon buttons in the bottom Home controls.

Tapping `Check In` opens the existing `PlaceCheckInMapSheet` with no preselected activity. Tapping `Sleep` starts the same sleep flow as the former dock, including the focus-timer warning when needed.

Activity selection, suggested saved places, current-location capture, active-session review, and history editing stay inside the map/check-in surface instead of appearing as a persistent Home banner.

## Consequences

- Home keeps check-in and sleep reachable without dedicating large persistent rectangles to single-purpose entry points.
- The map/check-in sheet remains the durable place capture and review surface on iOS.
- Sleep remains a Home-level entry point and still honors the Settings visibility toggle.
- The shared `PlaceCheckInDockView` can remain available for surfaces that still need the full inline dock behavior.
