# 0594: Simplify iOS Task Detail Scan and Action Hierarchy

## Status

Accepted

## Date

2026-08-16

## Revises

- [0584: Group iOS Task Maintenance in Navigation Overflow](0584-group-ios-task-maintenance-in-navigation-overflow.md) for the simple todo completion card only

## Refined By

- [0595: Keep Task Completion Colors Consistent Across Platforms](0595-keep-task-completion-colors-consistent-across-platforms.md)

## Refines

- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0264: Match Button Hit Areas to Visual Surfaces](0264-match-button-hit-areas-to-visual-surfaces.md)
- [0507: Clarify iOS Task Detail Action Hierarchy](0507-clarify-ios-task-detail-action-hierarchy.md)
- [0508: Keep iOS Add More Details Last](0508-keep-ios-add-more-details-last.md)
- [0585: Persist iOS Task Detail Calendar Expansion Per Task](0585-persist-ios-task-detail-calendar-expansion-per-task.md)
- [0586: Group iOS Task Detail Priority Context in the Header](0586-group-ios-task-detail-priority-context-in-the-header.md)

## Context

iOS Task Details gave an ordinary unfinished todo a permanent `Selected / Today`
badge even though today is the default and the selected date matters visibly only
after the person chooses another day. The todo completion button also followed
Calendar and sat inside an otherwise empty outlined card. Four related priority
signals stacked vertically, the navigation title showed only an emoji, and the
`Add more details` badge presented a bare number with no explanation.

Each element was understandable alone, but together they made the compact screen
longer, visually fragmented, and slower to scan than its primary view-and-complete
journey required.

## Decision

On iOS Task Details:

- an active todo selected on today shows Status without a redundant selected-date
  badge; choosing another date adds `Viewing / <date>` because completion, undo,
  checklist, cancellation, and future-date availability can depend on that day;
- the todo primary action follows the header and precedes notification context and
  Calendar;
- a simple todo completion button has no empty outer card, while the card remains
  when State, timing, or relationship-blocking context needs to stay grouped;
- visible Importance, Urgency, Pressure, and Thinking needed controls keep their
  established order in an adaptive flow that normally forms compact rows and
  stacks at accessibility Dynamic Type sizes;
- those priority controls use semibold labels, visible strokes, explicit
  accessibility labels and values, and a 44-point-high visible target;
- the navigation principal combines the task emoji with a single-line,
  width-bounded task name; and
- `Add more details` labels its badge as `1 option` or `<count> options`.

Calendar remains a task-owned persistent disclosure, `Add more details` remains
last, selected-date behavior is unchanged, and macOS presentation is unchanged.

## Consequences

- The ordinary todo screen prioritizes identity, state, and completion before
  optional date review.
- A non-today action target stays explicit even after Calendar is collapsed.
- Related task-choice signals use less vertical space without sacrificing order,
  touch size, color-independent labels, or larger-text support.
- Card chrome communicates grouping only when grouped context exists.
- Navigation and progressive disclosure explain themselves with little extra copy.
