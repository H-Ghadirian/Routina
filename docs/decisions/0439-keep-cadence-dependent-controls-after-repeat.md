# 0439 — Keep Cadence-Dependent Controls After Repeat

Status: Accepted

Date: 2026-07-26

Refines: [0058 Use Progressive Task Forms](0058-use-progressive-task-forms.md), [0186 Put Item Runout in Repeat Type](0186-put-item-runout-in-repeat-type.md), [0188 Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md), [0431 Present One Progressive Recurrence Composer](0431-present-one-progressive-recurrence-composer.md), [0437 Compact Wide Mac Task Forms](0437-compact-wide-mac-task-forms.md)

Refined by: [0442 Keep Routine Planning Inside Schedule Details](0442-keep-routine-planning-inside-schedule-details.md)

## Context

Mac routine forms rendered Duration, Time availability, Due style, and the task
list preview before the Repeat control. `No schedule` hid those modules because
cadence was disabled. Choosing `Item runout`, `After done`, or `On schedule`
enabled cadence and inserted the modules above the control the user had just
changed.

The newly selected Repeat segment therefore moved down the page while
additional checklist timing controls appeared later in the Checklist card.
Although every revealed field was valid, the dependency flowed in both
directions on screen and made a single choice look like several unrelated
changes.

## Decision

Mac routine Behavior forms keep the cadence dependency in one stable order:

1. Completion.
2. Repeat.
3. Cadence-dependent schedule details.

Changing Repeat must not insert a module before the Repeat control. Duration,
Time availability, Due style, task-list preview, Nudges, and Auto-assume done
live in a collapsed `Schedule details` disclosure after Repeat. Its collapsed
label summarizes the current duration, timing, and applicable Due/Gentle
behavior so values remain visible without expanding the form.

The disclosure appears only when cadence is enabled and collapses when cadence
is disabled. Recurrence-specific fields such as frequency, weekdays, dates, and
fixed schedule options remain directly below the Repeat segments because they
are required to define the selected recurrence.

`Item runout` remains a Repeat choice. Its short explanation points to the
Checklist card, where the item title, `Every N days` interval, and Add action
stay together in one local composer row when space permits.

This changes presentation only. Schedule values, validation, recurrence draft
state, persistence, and item-runout runtime behavior remain unchanged.

## Consequences

- The control a user changes does not move when its dependent settings appear.
- One cadence choice reveals at most one compact schedule-details row in the
  Behavior card.
- Existing non-default schedule values remain visible in the collapsed summary.
- Item-runout timing is explained and edited beside the checklist item it
  affects.
- Future progressive form modules must render after the control that enables
  them unless a separate accepted decision explicitly establishes another
  hierarchy.
