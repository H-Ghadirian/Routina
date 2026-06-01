# 0126 Show Focus Sessions in Timeline

- Status: Superseded
- Date: 2026-06-01
- Superseded by: [0129](0129-hide-abandoned-focus-sessions-from-timeline.md)

## Context

Focus timers already create planner representations while active and remain focus history for stats after they finish. That left Timeline without an immediate record when work began from a task or board timer, even though Timeline is the app's chronological evidence surface for what happened.

## Decision

Timeline shows focus sessions as first-class `Focus` entries at their start time. Task and unassigned focus sessions come from `FocusSession`; board focus sessions come from `SprintFocusSessionRecord` and use the linked board title when available.

Active, paused, completed, and abandoned task focus sessions can appear in Timeline so starting a timer leaves immediate evidence. Active board focus sessions also appear immediately and update to a finished range when stopped. Focus entries are visible in `All` and `Focus` Timeline filters, can inherit task tags and task importance/urgency when linked to a task, and remain excluded from media, done, missed, and canceled outcome filters.

## Consequences

- Timeline can answer "when did I start focusing?" for task, unassigned, and board timers without duplicating focus data.
- Focus history still remains distinct from routine completion/missed/canceled activity.
- Planner focus blocks and focus Timeline marks can coexist: the planner shows allocation, while Timeline shows chronological evidence.
