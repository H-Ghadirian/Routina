# Bug-Fix Lessons

This directory contains durable lessons learned from Routina bug fixes. Each fixed bug gets its own note so the cause and prevention guidance remain easy to find during later development.

## How to Use This Log

- After every bug fix, add one numbered Markdown note and add it to the index below.
- Name notes `NNNN-short-description.md`, using the next available four-digit number.
- Focus on reusable engineering knowledge rather than a chronological work summary.
- Link relevant decision records, regression scenarios, tests, and source files when useful.
- If several symptoms share one root cause and are fixed together, one lesson note is sufficient.
- If a later fix changes the understanding of an older lesson, add a new note and cross-link both rather than rewriting history.

## Note Template

```markdown
# NNNN — Short lesson title

Date: YYYY-MM-DD

## Symptom

What users or developers observed.

## Root Cause

Why the defect occurred.

## Fix

What changed to correct it.

## Prevention Rule

The concrete rule future development should follow.

## Regression Safeguard

Tests, scenarios, assertions, tooling, or review checks that protect against recurrence.
```

## Index

- [0001 — Number mixed timeline entries in display order](0001-number-mixed-timeline-entries-in-display-order.md)
- [0002 — Keep Timeline change detection out of the render path](0002-keep-timeline-change-detection-out-of-render-path.md)
- [0003 — Separate Home maintenance from refresh](0003-separate-home-maintenance-from-refresh.md)
- [0004 — Do not reload Stats on view reappearance](0004-do-not-reload-stats-on-view-reappearance.md)
- [0005 — Defer AppKit responder changes out of `updateNSView`](0005-defer-appkit-responder-changes-out-of-update-ns-view.md)
- [0006 — Keep expanded sidebar groups lazy and stably identified](0006-keep-expanded-sidebar-groups-lazy-and-stably-identified.md)
- [0007 — Keep Timeline row compositing and refreshes off the scroll frame](0007-keep-timeline-row-compositing-and-refreshes-off-the-scroll-frame.md)
- [0008 — Keep assumed completion visually distinct from recorded completion](0008-keep-assumed-completion-visually-distinct.md)
- [0009 — Never install empty Mac context menus](0009-never-install-empty-mac-context-menus.md)
- [0010 — Keep Mac sidebar context-menu tracking out of SwiftUI](0010-keep-mac-sidebar-context-menu-tracking-out-of-swiftui.md)
