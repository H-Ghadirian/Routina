# 0049: Filter Tasks and Done Items by Media

- **Status:** Accepted
- **Date:** 2026-05-14

## Context

Home task filters already support tags, goals, places, state, pressure, creation date, and importance/urgency. Timeline and done history support similar task-derived filters, but neither surface could answer a common review question: which tasks or completed items have attached evidence such as an image or file?

Images are stored directly on `RoutineTask`, while files are modeled as `RoutineAttachment` records linked back to a task. A media filter needs to combine those sources without changing the task data model or treating sleep and place sessions as task media.

## Decision

Routina uses a shared `TaskMediaFilter` with `All`, `Any Media`, `Image`, and `File` options. Home task lists apply the filter to visible and archived task rows. Timeline and done history apply the same filter to task log entries, including the Done outcome filter, by deriving image presence from the task and file presence from linked attachment task IDs.

When a media filter is active, non-task timeline entries such as sleep sessions and place check-ins are excluded because they do not currently own task images or task file attachments.

## Consequences

- Home task filtering and Timeline/Done filtering stay aligned and can share labels, icons, persistence, and matching logic.
- File filtering depends on each platform view keeping attachment task IDs in sync from SwiftData queries.
- Future media-bearing entities outside tasks should either extend the shared media filter model or explicitly define why they remain excluded.
