# 0691: Split Focus Activity Across Local Days

## Status

Accepted

## Date

2026-08-29

## Revises

- [0118: Show Focus Chart Details and Grouping](0118-show-focus-chart-details-and-grouping.md)
- [0137: Show Active Focus in Stats Today](0137-show-active-focus-in-stats-today.md)

## Refines

- [0005: Show Timeline Activity in Day Planner](0005-show-timeline-activity-in-day-planner.md)
- [0123: Pause Focus Timers](0123-pause-focus-timers.md)
- [0129: Hide Abandoned Focus Sessions from Timeline](0129-hide-abandoned-focus-sessions-from-timeline.md)
- [0415: Support Custom Stats Date Ranges](0415-support-custom-stats-date-ranges.md)
- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0598: Count Semantic Focus Session Copies Once in Stats](0598-count-semantic-focus-session-copies-once-in-stats.md)

## Context

Focus history stores a session-level start, terminal timestamp, and total paused
duration. It also records exact Pause and Resume actions. Timeline previously
placed a completed Focus session on its start day, while Stats placed its entire
duration on the day that Finish was pressed. A session paused yesterday and
finished today could therefore make today's Stats claim time that was actually
focused yesterday.

Completion-day bucketing also cannot describe a continuous session that crosses
midnight. A Focus interval from 23:00 to 03:00 represents one hour on the first
day and three hours on the second, regardless of when the person presses Finish.

## Decision

- Routina derives task, tag, unassigned, and board Focus evidence from uninterrupted active intervals. Persisted Pause and Resume actions identify the exact boundaries of those intervals; paused wall-clock gaps and a later Finish action contribute no Focus time.
- Each active interval is intersected with local calendar-day boundaries before Timeline and date-range Stats derive their presentation. A continuous 23:00-03:00 interval contributes one hour to the first day and three hours to the second.
- Timeline presents one Focus row for each occupied local day. When a session has several active intervals on one day, that row uses the first active start and last active end as its visible bounds and sums only the active durations. Continuation rows use deterministic identities so list selection and rendering remain stable.
- Focus duration and hourly Stats use the same resolved intervals. A selected range counts only the portions that intersect that range, and hourly rhythm assigns every portion to its actual local hour.
- Semantic Focus-session copies are canonicalized before interval derivation, preserving the existing count-once rule.
- Older synchronized records may contain aggregate paused duration without the corresponding Pause and Resume actions. Because exact historical pause placement cannot be recovered, Routina preserves the authoritative active-duration total and anchors that total at the recorded start. It does not assign that duration to a later terminal-action day merely because Finish was pressed then.
- Interval and day-slice derivation occurs while building reducer-owned or cached presentation snapshots. Scrolling row builders reuse those results and do not fetch or reconstruct Focus history.

## Consequences

- Timeline and Stats tell the same day-by-day story for overnight and interrupted Focus.
- Pressing Finish while a timer is paused does not create a Focus row or Stats duration on the finish day unless an active interval actually occupied that day.
- One logical session can appear as multiple daily Timeline rows while remaining one persisted Focus session and one semantic session for canonicalization and contribution counts.
- New records with action history retain exact pause placement. Legacy aggregate-only records retain correct total duration but cannot recover unknowable historical placement within the session's wall-clock span.
