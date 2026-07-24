# 0426: Collapse Mac Task Form Tag Suggestions

## Status

Accepted

## Date

2026-07-24

## Context

The Tags section in Mac Add Task and Edit Task showed every saved tag as a chip. As a user's tag collection grew, this suggestion list occupied several lines and made an optional form section increasingly noisy.

## Decision

Mac task forms always show the tags already selected for the draft and any contextually related suggestions. The remaining saved-tag suggestions default to the six most-used tags, using the existing task-link and completion usage ordering. A disclosure control lets the user show the complete saved-tag list and collapse it again.

## Consequences

- Existing tags remain searchable through autocomplete even while the chip list is collapsed.
- Common tags stay one click away without allowing the default form height to grow with the full tag catalog.
- Add Task and Edit Task share the same compact behavior.
