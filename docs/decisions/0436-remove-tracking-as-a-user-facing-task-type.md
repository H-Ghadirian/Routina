# 0436 Remove Tracking as a User-Facing Task Type

Status: Accepted

Date: 2026-07-26

Supersedes the compatibility-surface decision in [0428 Compose Tracking Behaviors on Gentle Routines](0428-compose-tracking-behaviors-on-gentle-routines.md) and the visible Tracking surfaces introduced by [0383 Use Tracking as Record Label](0383-use-tracking-as-record-label.md), [0384 Show Tracking as Mac Sidebar Section](0384-show-tracking-as-mac-sidebar-section.md), [0388 Show Tracking Summary Stats](0388-show-tracking-summary-stats.md), and the Tracking rule in [0411 Manage Custom Task Sections in Settings](0411-manage-custom-task-sections-in-settings.md).

## Context

The task form no longer offers `Track this routine`, and users can compose the
same useful behavior directly on a repeating routine through Gentle cadence,
optional Nudges, and eligible Auto-assume done.

Keeping Tracking in Home filters, Timeline filters, Stats, Settings, badges, or
sidebar sections would therefore expose an orphan product category that users
cannot deliberately create or meaningfully distinguish from a routine. Routina
has not been publicly released, so there is no production user data that
requires a visible compatibility surface.

## Decision

Routina presents only `Routines` and `Todos` as task-type categories:

- Add and Edit forms use `One-time` and `Repeating`.
- `Tracking` is not a Flag, and no `Track this routine` compatibility control is shown.
- Home and Timeline filters do not offer Tracking.
- Mac Home has no dedicated Tracking section.
- Stats has no Tracking filter, count, time card, or dashboard item.
- Settings custom-section rules do not offer Tracking.
- Search aliases, badges, empty-state copy, and task-kind labels do not expose
  Tracking.

The internal `record` task type is treated as a routine at presentation and
filtering boundaries. If an internal record-shaped fixture or development
database row is encountered, it appears with routines in Home, Timeline,
Planner, and Stats instead of recreating a Tracking surface.

Persisted names such as `trackingCadenceEnabled` and
`trackingNudgesEnabled` may remain temporarily as implementation details while
their storage is shared by routine behavior. They must not drive a separate
user-facing category. Obsolete pre-release filter or Settings values may fall
back to defaults or be ignored; no compatibility UI is required.

## Consequences

- Users see one coherent repeating-task model and can build the former tracking
  behaviors themselves.
- Filters, Stats, and Settings cannot imply that Tracking is a creatable or
  separately configurable task type.
- Internal storage cleanup can happen independently without blocking the
  product simplification.
- Future task-type additions must be introduced across creation, filtering,
  presentation, Stats, and Settings as one deliberate product concept.
