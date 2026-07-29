# 0460: Match Custom Section Tags by Any or All

## Status

Accepted

## Date

2026-07-29

## Refines

- [0449: Keep Custom Section Rules Tag-Based](0449-keep-custom-section-rules-tag-based.md)
- [0450: Use Progressive Custom Section Management](0450-use-progressive-custom-section-management.md)

## Context

Custom super sections could route an unassigned task when any configured tag
matched. That behavior works for broad areas, but it cannot express a narrower
intersection such as tasks tagged with both `Work` and `Deep Focus`.

The Settings editor also represented every configured tag inside one
comma-separated field. That made individual values harder to scan and remove
and did not offer the saved-tag suggestion and Tab-completion behavior used by
other Mac tag editors.

## Decision

Each custom super section stores a tag match mode:

- `Any` claims an unassigned task when at least one configured tag matches.
- `All` claims an unassigned task only when every configured tag matches.

Missing match-mode data decodes as `Any`, preserving existing section behavior.
An empty tag rule never claims a task in either mode. Tag comparison continues
to use Routina's case- and accent-insensitive tag identity, and manual section
assignments remain stronger than automatic rules.

Settings -> Sections presents the mode as a segmented control. Configured draft
tags appear as individually removable chips. A separate composer suggests
existing saved tags after typing begins and accepts the visible completion with
Tab, matching Routina's other Mac tag-entry surfaces. New tag names remain
allowed.

## Consequences

- Broad and intersection-based automatic sections can coexist.
- Existing saved sections keep their previous any-tag routing semantics.
- Users can scan and remove individual rule tags without editing comma syntax.
- Section tag entry remains consistent with task and goal tag autocomplete.
