# 0075: Treat Tags as Case-Insensitive Identities

## Status

Accepted

## Date

2026-05-26

Clarifies [0048](0048-tag-goals.md), [0063](0063-tag-standalone-notes.md), and [0064](0064-group-home-task-list-by-tags.md).

## Context

Tasks, goals, notes, filters, and settings all share the `RoutineTag` model. The normalized tag identity already ignores case and accents, but entry paths could still preserve a newly typed case variant when an existing tag used different capitalization. That made tags feel inconsistent even when filtering and summaries were mostly normalized.

## Decision

Tag identity is case-insensitive and accent-insensitive across task, goal, note, quick-add, filter, and settings flows.

When a user types a tag that matches an existing tag with different capitalization, the app keeps the existing display spelling instead of creating a new visual variant. Selected tag lists and smart-add parsed tags merge against existing tags by normalized identity before saving.

## Consequences

- `#Home`, `#home`, and `#HOME` behave as the same tag.
- Existing tag spelling remains stable when users type a different case.
- Future tag entry points should route through `RoutineTag` helpers instead of comparing raw strings.
