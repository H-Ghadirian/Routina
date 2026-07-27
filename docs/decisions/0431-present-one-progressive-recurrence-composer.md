# 0431 — Present One Progressive Recurrence Composer

Status: Accepted

Date: 2026-07-26

Refines: [0430 Unify Recurrence Editing Behind a Lossless Draft](0430-unify-recurrence-editing-behind-lossless-draft.md), [0412 Add Advanced Recurrence Beside Simple](0412-add-advanced-recurrence-beside-simple.md), [0178 Make Recurrence Availability Independent](0178-make-recurrence-availability-independent.md), [0186 Put Item Runout in Repeat Type](0186-put-item-runout-in-repeat-type.md)

Refined by: [0443 Present Fixed Schedule Options as One Grouped Mode](0443-present-fixed-schedule-options-as-one-grouped-mode.md)

## Context

The Simple / Advanced selector required users to choose a storage model before describing the behavior they wanted. Related controls were split across separate branches, ordinary schedules and fixed-anchor schedules looked mutually exclusive, and some structured collections such as several yearly months were stored without a matching editor.

Decision 0430 introduced a lossless recurrence draft so Add Task and Edit Task could share one authoritative form value without migrating the existing recurrence engines or persistence representations. The visible composer can now rely on that draft.

## Decision

iOS and macOS Add Task and Edit Task present one progressively disclosed recurrence composer. They no longer expose Simple and Advanced as user choices.

The composer starts with the recurrence intent:

- `No schedule` for a reusable routine with no automatic cadence.
- `After done` for a rolling interval measured from completion.
- `On schedule` for fixed calendar or fixed-anchor occurrences.
- `Item runout` when checklist completion supports it.

Frequency, interval, weekday, monthly pattern, month-date, and yearly month selectors appear only when the selected intent needs them. The yearly editor binds to the complete stored month and date collections rather than scalar compatibility values.

Fixed start, time zone, occurrence times, hourly windows, and ending conditions live under `More schedule options`. The disclosure opens automatically when the selected rule requires those fields. An optional fixed schedule may be simplified back to compact recurrence only when every active field can be translated without loss.

Date availability, time availability, routine duration, planning, deadline, reminder, Due/Gentle behavior, Nudges, and Auto-assume remain separate behavior modules. If the current runtime cannot combine fixed-anchor recurrence with a separate availability window, the form keeps the window visible and blocks save with an explicit validation message.

Compact and versioned structured recurrence remain internal persistence and runtime strategies. The composer writes the shared lossless draft; existing compatibility projections remain available for storage, sync, notifications, history, and older records.

## Consequences

- Users build ordinary and complex recurrence in one place without learning internal model names.
- Common schedules remain short; complex fields are progressively disclosed.
- Add and Edit use the same controls and support the same stored cardinality on both platforms.
- Switching cadence or enabling fixed details preserves exact-time intent and latent structured fields instead of clearing them.
- New recurrence capabilities must first be representable by the lossless draft and then receive a matching composer module and round-trip coverage.
- The legacy Simple / Advanced state remains internal during compatibility migration, but it is no longer user-facing.
