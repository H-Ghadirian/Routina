# 0397 Make Tracking Cadence Optional

Status: Accepted

Date: 2026-07-16

Refines: [0385 Use Gentle Routine Cadence for Tracking](0385-use-gentle-routine-cadence-for-tracking.md), [0396 Allow Quiet Tracking Cadence](0396-allow-quiet-tracking-cadence.md)

## Context

Some Tracking entries are recurring in the broad human sense, but not on a useful schedule. Requiring a repeat cadence for those entries creates fake structure: if nudges are off, the cadence may have no practical user-facing value.

## Decision

Tracking repeat controls include `None`. New Tracking entries can be record-only without cadence, while Tracking that benefits from loose rhythm can still choose interval, calendar, or item-runout cadence.

Routina stores `trackingCadenceEnabled` separately from `trackingNudgesEnabled`. When cadence is disabled, recurrence settings are treated as a neutral internal placeholder, Home and Task Detail do not surface soft-threshold/nudge behavior, and the form hides cadence-specific frequency/calendar and nudge controls. Existing imported/shared Tracking data defaults cadence on for compatibility.

## Consequences

Random or opportunistic Tracking can be captured without inventing a repeat rhythm.

Future Tracking features should treat cadence as optional context, not as a requirement for record-style tracking.
