# 0642 — Unify task configuration and retire legacy task-kind storage

Date: 2026-08-23

Status: Accepted

The macOS Changes over time editor and preview presentation is revised by
[0646](0646-compact-mac-changes-over-time-editing.md). iOS retains the detailed
preview described here.

## Context

Task configuration had grown as separate cards for Importance and Urgency, Pressure, Thinking needed, Tags, Path, Flags, and Task Ladder grouping. Task Details then hid some of the four Task Ladder values behind a Priority disclosure and showed a derived overall Priority whose calculation and purpose were unclear. The time-based rule was discoverable only through optional-detail menus, so a person could not easily understand its eligibility or preview what would happen after completion, during a gradual lead window, on the due date, and after the due date.

The pre-release codebase also retained a removed third task-kind enum case, matching schedule modes, storage names, schema fields, help aliases, migration branches, and regression fixtures. There is no released user data that requires that compatibility layer.

## Decision

Add Task and Edit Task use three primary configuration groups after identity:

- `Behavior & Schedule` owns one-time/repeating behavior, completion, cadence, availability, due style, and planning.
- `Task Ladder values` owns Importance, Urgency, Pressure, and Thinking as four independent values. `Changes over time` lives directly beneath them and either renders its editor or states the exact behavior/cadence choice required to enable it.
- `Organization` owns Path, Tags, Flags, and the repeating-task-only `Use as Task Ladder group` control.

Configured changes over time preview four meaningful states: after completion/next occurrence at Base, during the lead window, on the due date, and after the due date until completion. The preview shows the resulting Importance, Urgency, and Pressure targets without mutating Base values.

Task Details always shows the four directly editable Task Ladder values in one compact adaptive container. It has no aggregate Priority label, derived-priority badge, disclosure state, or add-detail action for those values. A configured Changes over time summary remains in that container and opens editing; initial configuration belongs to Add Task or Edit Task so the detail header stays focused.

The task domain and persistence schema contain only Routine and Todo kinds. Remove the obsolete kind case, matching schedule modes, compatibility-only visibility field, old cadence field aliases, import fallbacks, help entries, migrations, and tests. Derived priority may remain as internal ranking/filter metadata, but it is not presented as a fifth user value.

## Consequences

- The same four-value mental model is used on iOS, macOS, creation, editing, Task Details, and Task Ladder.
- Core values are never hidden merely because they equal defaults, while optional rich content can still use progressive disclosure.
- Time-based behavior is discoverable without crowding Task Details and is understandable before saving.
- Path and Task Ladder grouping no longer appear far away from Tags and Flags.
- Pre-release persistence and test code become smaller and cannot reintroduce removed product vocabulary.
- Removing the compatibility schema is intentionally not backward compatible with unreleased development stores.

## Revises and supersedes

- Supersedes the optional aggregate-priority presentation in [0424](superseded/0424-make-task-detail-priority-optional.md) and the expandable Mac card in [0564](superseded/0564-group-mac-task-priority-controls.md).
- Revises the form hierarchy in [0100](0100-reveal-task-form-details-by-section.md), [0437](0437-compact-wide-mac-task-forms.md), [0462](0462-use-a-compact-progressive-ios-task-editor.md), [0534](0534-present-ios-priority-controls-in-dedicated-sheets.md), [0563](0563-present-importance-and-urgency-as-independent-task-controls.md), [0586](0586-group-ios-task-detail-priority-context-in-the-header.md), and [0604](0604-edit-task-detail-values-inline.md).
- Supersedes the compatibility retention in [0436](superseded/0436-remove-tracking-as-a-user-facing-task-type.md).
- Refines time-based value configuration from [0592](0592-derive-time-based-task-ladder-values-from-repeating-due-dates.md).
