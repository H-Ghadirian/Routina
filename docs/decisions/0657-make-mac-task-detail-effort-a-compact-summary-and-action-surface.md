# 0657: Make Mac Task Detail Effort a Compact Summary and Action Surface

## Status

Accepted

## Date

2026-08-24

## Revises

- [0652: Keep Effort Fields Independent and Disclosures Honest](0652-keep-effort-fields-independent-and-disclosures-honest.md)
- [0653: Present Effort Values as Values, Not Feature Switches](0653-present-effort-values-as-values-not-feature-switches.md)
- [0655: Separate Mac Task Detail Actual Time and Focus Controls](superseded/0655-separate-mac-task-detail-actual-time-and-focus-controls.md)

## Context

Giving Actual time and Focus separate permanent inputs corrected their data
relationship but made expanded Effort behave like two configuration forms plus
a Focus analytics dashboard. Durations appeared in both steppers and presets,
Focus total/session/latest values repeated the recent-history information, and
wide windows separated each session from its edit action. The collapsed card
could still emphasize missing Actual time while omitting retained Focus history.

Focus enablement was also removable after a person had created sessions. That
could hide durable history and imply that the task no longer had Focus evidence
even though its sessions remained stored.

## Decision

- Collapsed Mac one-off Effort summarizes populated Estimate, Actual time,
  Focus, and Story points values. Missing Actual time is a fallback summary only
  when no populated value exists; retained Focus history is never omitted.
- Expanded Effort shows compact Actual time and Focus value/action rows. It does
  not repeat those same values in the expanded header.
- `Log time` / `Add time` and `Start focus` open focused popovers. Duration and
  Countdown/Count up choices are shown only while their action is being prepared,
  rather than remaining mounted in Task Details.
- Embedded Focus history uses one total-and-session summary in the Focus row and
  a bounded recent-session list. It omits the metric-tile dashboard and
  accumulated block visualization, and keeps duration plus edit action adjacent
  to each session.
- A task with an active or completed Focus session keeps Focus visible and
  available even if legacy storage has the enablement flag off. Add/Edit replaces
  the Focus toggle with a retained-session status once such evidence exists.
  Deleting every retained session restores the optional toggle.
- Actual time and Focus remain separate records. Neither action converts or
  copies one value into the other.

## Consequences

- Task Details reads as a review-and-action surface instead of an always-open
  configuration form.
- Collapsed Effort reports the evidence a person has actually recorded.
- Starting or logging work requires one deliberate secondary surface, while the
  ordinary task view stays compact.
- Focus history cannot disappear merely because a per-task switch changed.
- Standalone Focus cards may retain their richer history presentation; this
  decision specifically compacts the Focus history embedded inside Mac Effort.
