# 0546: Separate Mac Backlog From the Radar Sidebar

## Status

Accepted

## Date

2026-08-11

## Revised By

- [0632: Integrate Mac Workspaces in the Main Window](0632-integrate-mac-workspaces-in-the-main-window.md) replaces the separate Backlog window with a full-size workspace inside the main Mac window while preserving the off-radar data and behavior defined here.

## Context

The Mac Home sidebar is most useful when it is a short, deliberate radar of
work that needs current attention. Tasks intentionally kept out of that view,
including tasks carrying a `Hide tasks from normal task lists` Flag, still need
a durable home where they can be organized and edited without weakening the
main sidebar's focus.

The prior beta Board surface is limited to one-off tasks and sprint workflow.
It cannot act as the general Backlog because it neither includes routine tasks
nor provides the existing one-level custom-section hierarchy.

## Decision

Mac has a dedicated `Backlog` window opened from the Routinam app menu. It
uses the existing durable custom-section catalog with a stored surface:

- `radar` sections remain in the Home sidebar and preserve current behavior.
- `backlog` super sections and their one-level subsections place assigned tasks
  only in the Backlog window, removing them from the normal Home sidebar and
  its search fallback.

The Backlog window also has an automatic `Hidden by flag` group for active,
non-archived tasks hidden from normal task lists that do not yet have an
explicit Backlog path. Assigning one to a Backlog section moves it into that
section without changing its Flag behavior.

The Backlog builds its complete section/task presentation as a reducer-owned
snapshot when task data, Flag rules, or section preferences change. Its
scrolling rows only consume that snapshot. Selecting a row opens the existing
full Task Detail, including its Edit flow. Moving a task to Radar clears its
custom Backlog path.

## Consequences

- The main sidebar remains an attention-oriented radar instead of an archive of
  deferred work.
- Backlog sections and assignments are already covered by the custom-section
  preference backup path; adding the section surface is backward compatible,
  because older sections decode as `radar`.
- Board and sprint behavior stay beta-gated and unchanged.
- Completed one-off tasks hidden only by a Flag do not become an unbounded
  Backlog history. Explicitly assigned Backlog tasks remain findable in their
  chosen section.
