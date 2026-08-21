# 0628: Adapt Mac Task Detail Labels to Available Width

## Status

Accepted

## Date

2026-08-21

## Refines

- [0627: Group Mac Task Detail Tags and Flags](0627-group-mac-task-detail-tags-and-flags.md)
- [0499: Explain Applied Flags in Task Details](0499-explain-applied-flags-in-task-details.md)
- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)

## Context

The first shared Mac Task Detail card still placed Tags and Flags in separate
vertical groups even when their headings and few assigned chips could fit on one
line. Most tasks have only a small number of labels, so the common presentation
continued to spend more height than the content required.

A normal flow layout is not sufficient for the compact candidate because it can
wrap chips internally and still report that the overall horizontal container
fits. The presentation needs to test the complete unwrapped arrangement before
choosing it.

## Decision

Mac Task Details first offer one intrinsic-width horizontal row containing the
Tags heading and chips, a vertical divider when both groups exist, and the Flags
heading and chips. That candidate does not wrap or compress. It is selected only
when the complete row fits the card's available width.

When the complete row does not fit, the card falls back to separate Tags and
Flags rows with a horizontal divider. Each fallback row keeps its heading beside
its chips, and the chip collection may wrap when a group itself is unusually
large. A task with only one group uses the same fit-based behavior without an
empty group or divider.

## Consequences

- The usual small set of Tags and Flags consumes one compact line.
- Narrow details and larger label sets remain readable without truncating or
  squeezing chips.
- The adaptive choice reflects the rendered content and available width rather
  than an arbitrary label-count threshold.
