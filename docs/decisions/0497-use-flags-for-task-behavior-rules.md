# 0497: Use Flags for Task Behavior Rules

## Status

Accepted

## Date

2026-08-07

## Supersedes

- [0496: Use Extensible Per-Tag Task-List Rules](superseded/0496-use-extensible-per-tag-task-list-rules.md)

## Context

Tags organize and describe work across tasks and other content. They already carry organization-specific features such as colors, related-tag suggestions, filters, custom-section matching, and grouping. Attaching app behavior to tags makes an organizational label unexpectedly change how a task behaves.

Task behavior needs a separate, task-only identity that can grow without giving tags application semantics.

## Decision

Tasks store a separate collection of Flags. Flags are defined in Settings, assigned in the task editor, and may carry typed behavior rules. Tags do not carry application behavior rules.

The first Flag rule is `Hide tasks from normal task lists`. A task with any matching Flag is excluded from normal Home task-list placement, including pinned, planned, custom-section, future, grouped, and archived placement. The task remains active: its schedule, notifications, planning, Planner, Stats, and task count are unchanged.

Text search can reveal a matching hidden task in a presentation-only `Hidden by flag` result section. That result does not reassign normal section membership or expose the normal inline completion action. Flags themselves are included in text search.

Rule identity is a normalized flag identity plus rule kind, so each flag can have at most one copy of a given rule type. Flag definitions and rules sync through user preferences and are included in backup and restore; task flags follow the normal task sync, sharing, copying, and backup paths.

## Consequences

- Tags remain strictly organizational and continue to support their existing colors, relationships, filters, and section rules.
- Future app behavior adds a Flag rule kind rather than a tag feature or one-off task boolean.
- Visibility remains an input to cached task-list presentations, so no whole-history derivation is added to scrolling render paths.
- The prior tag-rule preference is retained only as inert historical data; it no longer affects task-list behavior.
