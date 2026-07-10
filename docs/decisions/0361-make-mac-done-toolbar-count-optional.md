# 0361: Make Mac Done Toolbar Count Optional

## Status

Accepted

## Date

2026-07-09

## Refines

- [0341: Consolidate Mac Home Toolbar Row](0341-consolidate-mac-home-toolbar-row.md)

## Context

The consolidated Mac Home toolbar made the Done count a top-level signal beside search and mode navigation. That kept completion progress visible, but it also made the primary toolbar carry a motivational counter at all times, even for users who prefer a quieter command surface.

The toolbar already has several conditional controls, and Settings is the right place for persistent display preferences that affect this chrome.

## Decision

Mac Home adds an Appearance -> Toolbar setting, `Show Done count in toolbar`, defaulting off. When the setting is off, the Home toolbar hides the green Done count badge. When enabled, the toolbar shows the same total Done count badge in the left status area.

The setting is persisted with the rest of app preferences, included in reset-to-default behavior, mirrored into user preferences, and preserved by backup and restore.

## Consequences

- The Mac Home toolbar is quieter by default.
- Users who want the completion counter can restore it without enabling a beta experiment.
- The Done count remains available in Stats and persisted history; only the toolbar badge is affected.
