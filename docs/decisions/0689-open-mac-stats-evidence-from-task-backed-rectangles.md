# 0689: Open Mac Stats Evidence from Task-Backed Rectangles

## Status

Accepted

## Date

2026-08-27

## Refines

- [0112: Show Estimated and Actual Time Stats](0112-show-estimated-actual-time-stats.md)
- [0113: Allow Stats Dashboard Reordering](0113-allow-stats-dashboard-reordering.md)
- [0188: Prefer Self-Explanatory UI over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0264: Match Button Hit Areas to Visual Surfaces](0264-match-button-hit-areas-to-visual-surfaces.md)
- [0359: Show Assumed-Done Stats Summary](0359-show-assumed-done-stats-summary.md)
- [0418: Keep Whole-History Work out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0415: Support Custom Stats Date Ranges](0415-support-custom-stats-date-ranges.md)
- [0668: Separate General Stats and Standardize Task-Type Language](0668-separate-general-stats-and-standardize-task-type-language.md)

## Context

Mac Stats summarized task evidence into prominent rectangles, but those values
were endpoints. A person who saw `Assumed done 32`, for example, could not
inspect which tasks and occurrences formed 32 without reconstructing the range
and filters elsewhere. The same gap applied to recorded outcomes, focus, task
inventories, and the activity overview.

A literal row per occurrence would reconcile the count but repeat the same task
many times. Building these lists during normal dashboard rendering would also
put additional history work on a scrolling render path.

## Decision

- On macOS, the complete visible surface of every task-backed Stats rectangle
  opens an anchored popover. The same action is available from keyboard focus
  and exposes button semantics to assistive technology.
- The activity overview, Daily average, and Best day list the tasks behind their
  activity evidence. Best day narrows the evidence to that day; the overview
  and average use the selected range.
- Done, Canceled, Missed, and Assumed done show each matching task once and put
  its contributing occurrence count beside it. Assumed time includes only
  tasks with a positive estimated-time contribution and shows the contributed
  duration. This preserves exact reconciliation without duplicate task rows.
- Focus time and Focus per day aggregate their underlying focus sources. A
  task-backed source uses the current task identity; unassigned, tag, or board
  focus remains visible as a named source so the displayed duration can still
  be explained completely.
- Repeating tasks, open One-time tasks, Active items, and Archived items list
  their matching current tasks. General Stats remains current-state evidence;
  Date Range Stats continues to honor the selected inclusive period.
- Every list honors the same task-type, matrix, query, Tag, and Flag filters as
  the rectangle that opened it. Non-task-backed rectangles remain static.
- A popover is an informational evidence view. It does not change task state or
  navigate away from Stats.
- The reducer-owned Stats refresh stores the matching task IDs with its derived
  metrics. The evidence presentation is built from that cached snapshot only
  after a deliberate click or key press, never from a scrolling `body` or card
  builder. The popover uses a lazy, bounded scrolling list.

## Consequences

- A summarized value has a direct audit path without requiring the person to
  leave Stats or reproduce its filters.
- High-frequency tasks remain readable because repeated occurrences are grouped
  under one task row while their counts or time stay explicit.
- Focus totals remain explainable even when part of the duration is not attached
  to a task.
- macOS gains this anchored inspection flow without changing iOS Stats or any
  persisted task and activity data.
