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
- [0011 — Route every collapsible sidebar group through persisted state](0011-route-collapsible-sidebar-groups-through-persisted-state.md)
- [0012 — Preserve scroll position across sidebar disclosure changes](0012-preserve-scroll-position-across-sidebar-disclosure-changes.md)
- [0013 — Do not expose fallback recurrence for cadence-free tasks](0013-do-not-expose-fallback-recurrence-for-cadence-free-tasks.md)
- [0014 — Present the Mac Add Task emoji picker as a sheet](0014-present-mac-add-task-emoji-picker-as-a-sheet.md)
- [0015 — Persist deliberately revealed task-detail controls](0015-persist-deliberately-revealed-task-detail-controls.md)
- [0016 — Defer Mac sharing-service discovery until selection](0016-defer-mac-sharing-service-discovery.md)
- [0017 — Bound growing form suggestion lists](0017-bound-growing-form-suggestion-lists.md)
- [0018 — Derive mirrored form labels from one section model](0018-derive-mirrored-form-labels-from-one-section-model.md)
- [0019 — Distinguish neutral defaults from explicit Quick Add metadata](0019-distinguish-neutral-defaults-from-explicit-quick-add-metadata.md)
- [0020 — Put hit shapes inside control labels](0020-put-hit-shapes-inside-control-labels.md)
- [0021 — Place shared actions before conditional actions](0021-place-shared-actions-before-conditional-actions.md)
- [0022 — Do not infer optional-section intent from legacy defaults](0022-do-not-infer-optional-section-intent-from-legacy-defaults.md)
- [0023 — Derive Stats comparisons from range duration](0023-derive-stats-comparisons-from-range-duration.md)
- [0024 — Fit chart annotations within chart bounds](0024-fit-chart-annotations-within-chart-bounds.md)
- [0025 — Keep preselected relationships resolvable](0025-keep-preselected-relationships-resolvable.md)
- [0026 — Clear detail selection on transient navigation](0026-clear-detail-selection-on-transient-navigation.md)
- [0027 — Preserve detail across transient Add Task](0027-preserve-detail-across-transient-add-task.md)
- [0028 — Preserve task context across Stats navigation](0028-preserve-task-context-across-stats-navigation.md)
- [0029 — Name linked-task actions by their destination](0029-name-linked-task-actions-by-destination.md)
- [0030 — Gate all recurrence behavior behind effective cadence](0030-gate-all-recurrence-behavior-behind-effective-cadence.md)
- [0031 — Preserve structured recurrence through edit state](0031-preserve-structured-recurrence-through-edit-state.md)
- [0032 — Use the structured-storage contract at sync boundaries](0032-use-the-structured-storage-contract-at-sync-boundaries.md)
- [0032 — Share relationship intent across linked-task entry points](0032-share-relationship-intent-across-linked-task-entry-points.md)
- [0033 — Match recurrence control cardinality to storage](0033-match-recurrence-control-cardinality-to-storage.md)
- [0034 — Drive recurrence editors from the lossless draft](0034-drive-recurrence-editors-from-the-lossless-draft.md)
- [0035 — Apply composed recurrence semantics at every runtime boundary](0035-apply-composed-recurrence-semantics-at-every-runtime-boundary.md)
- [0036 — Centralize occurrence resolution identity](0036-centralize-occurrence-resolution-identity.md)
- [0037 — Persist the selected occurrence timestamp](0037-persist-the-selected-occurrence-timestamp.md)
- [0038 — Keep Add Task autosave out of render paths](0038-keep-add-task-autosave-out-of-render-paths.md)
- [0039 — Gate appearance controls with feature availability](0039-gate-appearance-controls-with-feature-availability.md)
- [0040 — Retire product concepts across all presentation surfaces](0040-retire-product-concepts-across-all-presentation-surfaces.md)
- [0041 — Do not repeat complete form values as summaries](0041-do-not-repeat-complete-form-values-as-summaries.md)
- [0042 — Separate early completion time from scheduled occurrence](0042-separate-early-completion-time-from-scheduled-occurrence.md)
- [0043 — Pair optional actions with their render path](0043-pair-optional-actions-with-their-render-path.md)
- [0044 — Keep progressive controls after their trigger](0044-keep-progressive-controls-after-their-trigger.md)
- [0045 — Model planning as an additive projection](0045-model-planning-as-an-additive-projection.md)
