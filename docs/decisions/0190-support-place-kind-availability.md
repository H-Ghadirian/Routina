# 0190 Support Place Kind Availability

Status: Accepted

Date: 2026-06-09

Refines: [0187 Support Multiple Task Places](0187-support-multiple-task-places.md)

## Context

Multiple task places should not behave like a primary place plus passive metadata. If a task is linked to Home and Gym, being at either place should make the task available. Checking only the first selected place can show an incorrect `Away` badge or hide a task even though the user is at another selected place.

Some routines also belong to a category of places rather than one exact saved location. A grocery routine might be possible at any saved supermarket, even if the task was originally linked to one supermarket location.

## Decision

Home row availability checks every selected saved place. A task is available when the user is inside any selected place, unknown when location presence cannot be determined, and away only when the user is outside all matching places.

Saved places can carry an optional free-text kind, such as `Supermarket`, `Gym`, or `Office`. If a task is linked to a place with a kind, all saved places with the same normalized kind are treated as equivalent for availability. The task still stores its selected place IDs and keeps `placeID` as the first selected place for compatibility.

Kind matching is limited to saved Routina places. Routina does not infer arbitrary unsaved public points of interest from map data in this version.

## Consequences

Users can make a task available across multiple exact places or across saved places of the same kind without duplicating the task. Row metadata may name the matching place where the user currently is, while the task's stored selection continues to show the places the user explicitly linked.

Backup/import, CloudKit repair, summaries, and settings preserve the optional place kind so kind-based availability survives data transfer.
