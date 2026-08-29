# 0696: Use Grouped Rows for iOS Home Filter Choices

## Status

Accepted

## Date

2026-08-29

## Refines

- [0089: Prefer Native Apple Platform Patterns](0089-prefer-native-apple-platform-patterns.md)
- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0537: Keep All iOS Home Filter Options in Persistent Sheets](0537-keep-all-ios-home-filter-options-in-persistent-sheets.md)
- [0581: Separate iOS Priority Filter Controls](0581-separate-ios-priority-filter-controls.md)

## Context

The iOS Home Task Type detail used a three-segment control, One-time State used
wrapping chips, and the four Priority details used segmented controls that could
wrap into multiple rows. These presentations differed from the native inline
picker already used by Group rows and made longer labels, larger text, and the
ordered Priority choices harder to scan consistently.

Importance and Urgency also represent minimum thresholds, while Pressure and
Thinking needed are exact-match filters. Compact segment labels such as
`Medium+` and adjacent `All` / `None` choices did not make those different
semantics as clear as the dedicated sheets allow.

## Decision

iOS Home Task Type, One-time State, Importance, Urgency, Pressure, and Thinking
needed detail sheets use native inline pickers presented as grouped rows with a
trailing selection checkmark.

Task Type and One-time State rows keep recognizable symbols. Importance and
Urgency spell out their threshold choices, such as `Medium or higher`, while
Pressure and Thinking needed keep exact values. Their footers distinguish the
unfiltered `All` choice from `None`, which means the task has no recorded value.

The main Filters sheet continues to show compact current-value entries. The four
Priority filters remain independent, and selecting any row updates immediately
without dismissing its persistent detail sheet.

## Consequences

- These categorical filter sheets match Group rows, Task order, and other native
  inline picker details.
- Every option receives a full-width native row that adapts to Dynamic Type
  without wrapping a segmented control.
- Threshold and exact-match behavior is clearer without changing filtering,
  persistence, or dismissal semantics.
