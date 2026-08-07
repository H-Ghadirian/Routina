# 0496: Use Extensible Per-Tag Task-List Rules (Superseded)

## Status

Superseded by [0497: Use Flags for Task Behavior Rules](../0497-use-flags-for-task-behavior-rules.md)

## Date

2026-08-07

## Refines

- [0405: Show Hidden Scheduled Task Search Results](0405-show-hidden-scheduled-task-search-results.md)
- [0449: Keep Custom Section Rules Tag-Based](0449-keep-custom-section-rules-tag-based.md)

## Context

Tags describe useful task contexts, including low-attention tracking work that a person wants to retain without seeing in every ordinary task-list section. Archiving or pausing those tasks would change their lifecycle, notifications, planning, and active-task state, which is not the desired behavior.

Routina already has tag-based custom-section matching and related-tag suggestions, but neither describes a durable behavior owned by one tag. A one-off `isHidden` preference would solve the first request but make each later tag behavior another unrelated preference shape.

## Decision

Tag settings persist an extensible collection of typed per-tag rules. The first rule is `Hide tasks from normal task lists`.

A task carrying any tag with that rule is excluded from ordinary Home task-list placement, including pinned, planned, custom-section, future, tag-group, and archived rows. The rule does not archive, pause, modify scheduling, alter notifications, remove the task from Planner or Stats, or change the active-task count.

Text search and an explicit filter for the hiding tag reveal matching tasks in a presentation-only `Hidden by tag` result section. The result section does not reassign normal section membership or offer normal inline completion actions. It appears alongside ordinary search results when both exist.

Rule identities are the normalized tag identity plus rule kind, so a tag cannot accumulate duplicate copies of the same rule. Global tag rename carries rules to the replacement identity and tag deletion removes them. Rules sync through the existing user-preference channel and are included in backup and restore.

## Consequences

- Future tag behaviors add a new rule kind and UI option without replacing stored visibility state.
- Visibility filtering is an input to cached task-list presentations, keeping whole-collection work out of scrolling render paths.
- `Rules` in Tag Settings is distinct from the `Section rules` that determine automatic custom-section placement.
