# 0585: Persist iOS Task Detail Calendar Expansion Per Task

Status: Accepted

Date: 2026-08-16

Refines: [0089 Prefer Native Apple Platform Patterns](0089-prefer-native-apple-platform-patterns.md), [0100 Reveal Task Form Details by Section](0100-reveal-task-form-details-by-section.md), [0393 Persist Task Detail Heatmap Per Task](0393-persist-task-detail-heatmap-per-task.md), and [0425 Make Task Detail History Optional](0425-make-task-detail-history-optional.md)

## Context

The iOS Task Details calendar was always expanded. Its month grid and legend occupied a large part of the compact screen even when the person only needed the task's current status or primary action.

A session-only disclosure would make the screen shorter temporarily, but it would forget an explicit choice when the person left and returned to the same task. A global disclosure preference would also make expanding one task change every other task.

## Decision

iOS Task Details presents Calendar as a full-width disclosure card. The complete visible header is clickable and exposes its collapsed or expanded state to accessibility.

Calendar is collapsed by default for existing and new tasks. Expanding or collapsing it stores the state on the selected task. Future iOS Task Details visits restore that task's last calendar state while other tasks retain their own state.

The task-owned state participates in synchronization, task copying, and backup/import. macOS Task Details presentation is unchanged.

## Consequences

- The default iOS task-detail journey gives more space to current task context and actions.
- A person can keep the calendar open for tasks where date review is important without expanding it everywhere.
- Collapsing the calendar again is durable rather than a temporary screen-state change.
- Older synchronized or backed-up tasks without the field safely default to collapsed.
