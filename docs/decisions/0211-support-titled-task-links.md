# 0211: Support Titled Task Links

## Status

Accepted

## Date

2026-06-11

## Context

Task links can point to long ticket, document, dashboard, or reference URLs. Showing the raw URL in add/edit and task detail makes task context harder to scan, especially when multiple links are attached.

## Decision

Task links support an optional display title alongside the sanitized HTTP/HTTPS URL. `RoutineTask.link` remains the first URL for legacy compatibility, `RoutineTask.links` remains a URL-only compatibility view, and `RoutineTask.linkItems` carries titled link metadata. Existing JSON arrays of link strings still decode, while new storage can preserve titled link objects.

Task add/edit forms show title and URL fields per link row. Task detail renders the title when present and hides the raw URL from the visible row while keeping the URL as the actual destination.

## Consequences

- Existing URL-only links keep working and continue to render as their URL until a title is added.
- Backup/import, task sharing, and CloudKit direct-pull repair preserve titled links while retaining URL-only fallback fields for older payloads.
- Code that only needs URLs can continue using `links`; UI and metadata-preserving flows should use `linkItems`.
