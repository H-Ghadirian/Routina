# 0396 Allow Quiet Tracking Cadence

Status: Accepted

Date: 2026-07-16

Refines: [0385 Use Gentle Routine Cadence for Tracking](0385-use-gentle-routine-cadence-for-tracking.md)

Refined by: [0397 Make Tracking Cadence Optional](0397-make-tracking-cadence-optional.md)

## Context

Tracking can repeat with loose routine cadence, but not every recurring thing should become a nudge. Some tracking happens irregularly or only after a while; for those items, the useful behavior is recording entries whenever they happen, without Routina surfacing them as ready or gently due.

## Decision

Tracking keeps repeat cadence and implicit Gentle schedule behavior. Each Tracking task stores a `trackingNudgesEnabled` preference that defaults to enabled for backward compatibility.

When `trackingNudgesEnabled` is disabled, the task keeps its cadence metadata for history, repeat context, backup, import, and sharing, but Home and Task Detail suppress Ready/Gentle-nudge soft-threshold presentation for that item. Non-Tracking tasks normalize the preference to enabled.

## Consequences

Users can keep loose repeat context while recording opportunistically.

Future Tracking cadence features should keep cadence separate from pressure-oriented nudge presentation.
