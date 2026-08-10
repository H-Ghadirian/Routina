# 0531: Keep iOS Task Tag Selection Compact and Searchable

## Status

Accepted

## Date

2026-08-10

## Refines

[0426: Collapse Mac Task Form Tag Suggestions](0426-collapse-mac-task-form-tag-suggestions.md) for the iOS task-form experience.

## Context

iOS Add Task and Edit Task rendered every saved tag as an inline chip. A growing tag catalog made the optional Tags section look intimidating, pushed the rest of the form far down the screen, and made ordinary form updates do work proportional to the full catalog.

## Decision

iOS task forms always keep selected tags and contextual related-tag suggestions visible. They show only the six most-used remaining saved tags inline, using the existing usage ordering.

`Browse all tags` opens a dedicated searchable picker for the full catalog. The picker supports multiple selections without dismissing, keeps selections plainly marked, and lets the existing inline composer continue to create tags or accept autocomplete. Its displayed list is rebuilt when the search query or saved-tag catalog changes, rather than filtering the whole catalog from its scrolling view body.

## Consequences

- Adding common or contextually related tags remains one tap away.
- Large tag catalogs no longer expand the Add Task or Edit Task form by default.
- Every saved tag remains discoverable through both autocomplete and the searchable picker.
- The full catalog is only prepared after the person deliberately opens the picker, and the picker uses native list virtualization for its rows.
