# 0315: Merge Mac Quick Add Into Toolbar Search

## Status

Accepted

## Date

2026-06-29

## Refines

- [0074: Parse Mac Add Task Title](0074-parse-mac-add-task-title.md)
- [0278: Open Single Mac Add Action Directly](0278-open-single-mac-add-action-directly.md)
- [0310: Show Mac Home Toolbar Search](0310-show-mac-home-toolbar-search.md)

## Context

Mac Home had two fast text entry surfaces: the global toolbar search field for finding tasks and timeline entries, and a separate Spotlight-style Quick Add overlay opened by the configurable Quick Add shortcut. Both started with typing into a search-like field, but they forced users to choose search versus creation before entering the text.

The toolbar search field is already the global Home entry point and keeps AppKit first responder ownership stable while Home filters update.

## Decision

The configurable Mac Quick Add shortcut focuses the Mac Home toolbar search field instead of opening a separate overlay. Typing in that field continues to live-filter tasks, Timeline-style lists, Planner List entries, and task-backed Planner Calendar items.

Pressing Return in the toolbar search field submits the current query. If the query is non-empty and does not match an existing task or timeline result in the Home search domain, Routina creates a task through the shared Quick Add parser and persistence service. Successful creation clears the search and shows the existing created-task toast. Subscription limits open the existing paywall, and creation errors are shown as a Home alert.

The toolbar Add button and explicit Add Task commands still open the full Mac Add Task form. The full form remains the rich editing path, while the toolbar search owns the fast search-or-create path.

## Consequences

Users can press the same shortcut, type once, and either find existing work or create new work from the same Home toolbar field.

Future Mac Home search changes should preserve the no-results guard before creating from Return so normal search typing does not accidentally create duplicates or tasks that already have visible matches.
