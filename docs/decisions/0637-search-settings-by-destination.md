# 0637: Search Settings by Destination

## Status

Accepted

## Date

2026-08-22

## Context

Settings contains enough destinations that scrolling the sidebar or grouped
iOS list is slower than remembering the name of the preference. Search should
help a person reach a destination without changing the form's own controls or
searching personal task content.

## Decision

iOS and macOS Settings expose a native `Search Settings` field at the list or
sidebar level. It filters visible Settings destinations by their title, stable
aliases, and user-facing concepts inside each destination (for example,
`backlog` matches Sections while `hide` matches the Flags behaviors). When a
query matches an inner concept, the result row shows the matching control names
as context before the person opens the existing Settings navigation path. The
detail form remains unchanged, and an explicit empty state explains when no
destination matches. Feature-gated destinations remain excluded from results.

## Consequences

- People can use the same familiar search gesture on both platforms.
- Search stays predictable and fast because it searches a bounded catalog of
  destinations and curated control concepts, not task history or every control
  value.
- A result explains the relationship between its destination and the query,
  such as `Flags` → `Hide from Task Lists`, `Hide from Timeline`, or `Hide from
  Task Ladder`.
- Existing sidebar widths and navigation behavior remain unchanged.
