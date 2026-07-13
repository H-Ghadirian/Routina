# 0064: Group Home Task List by Tags

- **Status:** Accepted
- **Date:** 2026-05-26
- **Refined by:** [0314 Remove Status Grouping and Collapse Deadline Groups](0314-remove-status-grouping-and-collapse-deadline-groups.md), [0379 Separate Deadline Status in Tag Task List](0379-separate-deadline-status-in-tag-task-list.md)

## Context

The Home task list can show routines and todos together, but status-based buckets can become noisy when the user is thinking by area, project, or context. Tags already act as the shared organization vocabulary for routines, todos, goals, notes, timeline filters, and settings.

## Decision

Home list grouping includes a Tags mode alongside Status and Deadline Date. In Tags mode, active unpinned routines and todos are grouped by their first normalized tag, with untagged rows placed in a `No Tags` section. Pinned rows and archived rows remain their own sections so priority and lifecycle affordances stay predictable.

Each tag group is independently collapsible, and collapsed tag sections are persisted as local view state. A multi-tag task appears once, under its first tag, to keep row counts and drag ordering clear.

## Consequences

- Users can keep the combined routines/todos list cleaner without changing task data or filters.
- Tags become a primary Home organization option, so future Home list behaviors should preserve first-tag grouping semantics unless a new decision supersedes this one.
- Drag/manual ordering in Tags mode resolves within tag section keys instead of status section keys.
