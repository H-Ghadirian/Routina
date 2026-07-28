# 0454: Adapt Planner Hour Heights to Visible Density

Date: 2026-07-28

Status: Accepted

Supersedes: [0282 Expand Day Planner Hour Spacing](superseded/0282-expand-day-planner-hour-spacing.md)

Refines: [0191 Support One-Day Planner View](0191-support-one-day-planner-view.md), [0269 Support Planner Slot Actions](0269-support-planner-slot-actions.md), [0304 Place Day Spacing Controls in Time Header](0304-place-day-spacing-controls-in-time-header.md), [0418 Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)

## Context

Planner previously used one uniform visual height for every hour. Cards kept a
minimum rendered height for selection and resize access, but a stored interval
shorter than 15 minutes could either be enlarged semantically or drawn over the
following short card. Twelve exact five-minute tasks in one hour therefore
could not remain both truthful and independently usable.

Duration is domain data. A visual accommodation must not rewrite a task
estimate, completion duration, Planner interval, conflict interval, or label.
The Schedule needs a presentation transform that creates space where visible
density requires it.

## Decision

Planner Calendar `Schedule` uses a piecewise time axis with one visual height
per clock hour. Every hour starts at the range's normal base height. If a
short interval's minimum rendered card height would intrude into the next
non-overlapping visible interval on the same date, the hours between their
start times expand enough to separate the cards. An isolated short interval
keeps the normal hour height and may use its minimum card height without
creating unnecessary empty Schedule space.

For multi-day ranges, all visible date columns share the maximum required
height for each clock hour. Their hour lines therefore remain horizontally
aligned while only dense hours expand. Day-mode spacing controls still set the
base hour height; 3 Days and Week retain their compact base height but may
expand individual dense hours.

The same cached time axis owns:

- grid lines and labels;
- block, draft, live-session, drop-preview, and current-time geometry;
- scroll anchors;
- slot selection and quarter-hour snapping;
- drag/drop targeting; and
- resize delta conversion.

The axis is frozen for the duration of an active drag or resize so geometry
cannot move under the pointer. Its input is limited to already-derived blocks
for the visible dates and contains no SwiftData fetch or whole-history
derivation.

The 15-minute value remains an input convention for empty-slot and drop
snapping. It is not a storage minimum. Synthetic activity, explicit blocks, and
completion estimates may retain any valid whole-minute duration down to the
one-minute storage minimum.

## Consequences

- Exact five-minute intervals remain five minutes in storage, labels, conflict
  detection, and completion data.
- Dense hours grow vertically enough to keep sequential short cards from
  visually overlapping; isolated short cards and ordinary hours remain compact.
- Multi-day hour lines stay aligned across columns.
- Real concurrent intervals still use horizontal overlap columns.
- All visual and pointer math must route through the shared time axis; adding a
  uniform `minute / 60 * hourHeight` calculation to Schedule would reintroduce
  drift.
- Axis rebuilding stays bounded to visible snapshot data and reuses a cached
  immutable result while scrolling.
