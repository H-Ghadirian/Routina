# 0640: Route Unassigned Backlog Candidates by Tags

## Status

Accepted

## Date

2026-08-23

## Refines

- [0546: Separate Mac Backlog From the Radar Sidebar](0546-separate-mac-backlog-from-the-radar-sidebar.md)
- [0633: Make Mac Backlog Hierarchical and Searchable](0633-make-mac-backlog-hierarchical-and-searchable.md)
- [0460: Match Custom Section Tags by Any or All](0460-match-custom-section-tags-by-any-or-all.md)

## Context

Backlog super sections expose the same automatic tag editor as Main task list
super sections, but Backlog previously evaluated only explicit section IDs.
Creating a tagged Backlog super section therefore left active tasks in the
`Hidden by flag` group even when their tags clearly matched the new section.

## Decision

Backlog automatic tag rules claim unassigned Backlog candidates in the cached
presentation. A candidate is active, unfinished, uncanceled, hidden from the
normal task lists by a configured Flag, and has no custom section assignment.
The first matching top-level Backlog super section in catalog order receives
the task for presentation; `Any` and `All` tag matching use the existing
super-section rule semantics.

Explicit assignments remain stronger than automatic rules, whether the task
is assigned to a Backlog section or a Main task list section. Ordinary Radar
tasks are not pulled into Backlog merely because their tags match. Subsections
remain manual buckets and are never automatic destinations. Automatic routing
does not persist a custom-section ID; moving the task explicitly still uses
the existing durable assignment flow.

## Consequences

- Creating or editing a tagged Backlog super section immediately classifies
  matching unassigned hidden tasks without rewriting task data.
- Unmatched candidates remain visible in `Hidden by flag`.
- A deliberate section assignment is stable and cannot be overridden by a
  later tag-rule edit.
