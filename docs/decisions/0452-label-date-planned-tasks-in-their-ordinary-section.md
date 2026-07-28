# 0452: Label Date-Planned Tasks in Their Ordinary Section

Date: 2026-07-28

Status: Accepted

Refines: [0252 Stabilize Home Task List Presentation Identity](0252-stabilize-home-task-list-presentation-identity.md), [0440 Treat Day Planning Sections as Additive](0440-treat-day-planning-sections-as-additive.md), [0418 Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)

## Context

Additive planning intentionally shows one task in both `Today` and its ordinary
Pinned, custom, or Future placement. The Today copy is self-explanatory, but the
ordinary copy did not explain why the same task appeared twice. Its existing
status badge such as `To Do` describes lifecycle state, not the user's date-only
planning intention.

Automatically scheduled calendar routines can also appear in Today, but that
does not mean the user explicitly chose a `Plan to do` date.

## Decision

When a task's effective date-only planned date is today, its ordinary Mac Home
row shows a compact `Planned today` label. The label appears alongside the row's
secondary labels and remains independent from the lifecycle status badge.

The task's copy inside the `Today` section does not repeat the label because its
section already provides that context. Daily routines and calendar routines
that enter Today only through cadence are not labeled as planned.

The task IDs that qualify for the label are stored in the cached task-list
presentation snapshot. Row rendering performs only stable set membership and
does not rescan or re-filter the full task collection.

## Consequences

- An ordinary custom-section, Pinned, or Future row explains its connection to
  the user's working plan.
- `Planned today` and statuses such as `To Do`, `In Progress`, or `Blocked` can
  coexist because they describe different dimensions.
- Today rows stay concise, and schedule-driven visibility is not described as
  manual planning.
- The label remains correct across filters and presentation refreshes without
  adding whole-list work to the scrolling render path.
