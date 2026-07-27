# 0443 — Present Fixed Schedule Options as One Grouped Mode

Status: Accepted

Date: 2026-07-27

Refines: [0188 Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md), [0431 Present One Progressive Recurrence Composer](0431-present-one-progressive-recurrence-composer.md), [0437 Compact Wide Mac Task Forms](0437-compact-wide-mac-task-forms.md)

## Context

The unified recurrence composer correctly placed fixed start, time zone,
occurrence time, and ending conditions under `More schedule options`, but its
expanded presentation blurred two different states. The disclosure controlled
visibility, while a default Mac checkbox controlled whether fixed scheduling
was active. The checkbox sat inside a centered bounded frame, making the
controls appear detached from their disclosure.

For weekly, monthly, and yearly schedules, `Start` also displayed a time while
a separate `At` control displayed the same occurrence time. The two values have
different storage roles—the start timestamp is also the schedule threshold—but
showing both asked users to keep one intended time synchronized manually.

## Decision

`More schedule options` remains a disclosure that only shows or hides advanced
controls. Inside it, optional fixed scheduling is a clearly labeled
`Fixed schedule` mode rendered with a switch. When the selected recurrence
requires fixed details, the composer shows a noninteractive `Required` status
instead of a disabled switch.

The expanded controls live in one subtle, leading-aligned inset panel. Desktop
forms keep the panel at a readable width and show a trailing collapsed summary
of the fixed start and ending condition. Compact forms keep the shorter
disclosure label without forcing that summary into narrow space.

For desktop weekly, monthly, and yearly rules with one occurrence time, the
panel presents `Starts` as a date and `At` as the single time control on one
row. Other frequencies retain the layout needed for hourly anchors or multiple
daily times. When a non-hourly occurrence time or start day changes, the hidden
start timestamp aligns to the first occurrence time so the recurrence threshold
and the one visible time control cannot diverge.

The existing explanation remains visible only when fixed details are mandatory.
Recurrence storage, time-zone identity, end conditions, occurrence generation,
and compact-versus-structured persistence remain unchanged.

## Consequences

- Disclosure state and schedule-mode state have distinct visual roles.
- Optional fixed scheduling has the visual weight appropriate for enabling a
  group of subordinate fields.
- Required schedules do not present a disabled control that appears actionable.
- Desktop advanced fields stay visually connected to their disclosure.
- Single-time schedules no longer ask users to edit the same intended time
  twice.
- No persistence migration is required.
