# 0025: Show Place Check-In History Markers on the Map

## Status

Accepted

## Date

2026-05-12

## Context

Place check-ins store coordinate snapshots so history remains meaningful even if saved places are renamed, moved, or deleted. The Places map already showed saved-place radii and current location, but prior check-ins were not visible as map evidence unless they were raw current-location sessions on the selected day.

Users need the map to answer "where have I checked in before?" without having to page through the Day timeline.

## Decision

The Places map renders check-in history markers for all sessions that have coordinates. Markers are grouped by rounded coordinate so repeated check-ins at the same place produce one marker with a count badge instead of overlapping pins. Active sessions remain visually distinct from finished history. The map camera includes history marker coordinates when fitting the initial region.

## Consequences

- Saved-place check-ins and raw coordinate check-ins are both visible on the map.
- Repeated visits remain readable through count badges rather than stacked identical markers.
- The map becomes a history review surface in addition to a check-in surface, while the Day timeline remains the detailed edit/delete surface for individual sessions.
