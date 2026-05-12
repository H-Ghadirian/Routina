# Project Decision Log

This directory contains Routina's project decision records. These records are the source of truth for important choices that should guide future work.

## How to Use This Log

- Read this index and relevant decision records before making meaningful project changes.
- Add a new decision record when a change introduces or revises a long-term project decision.
- Prefer creating a new record that supersedes an older one instead of rewriting history.
- Keep records focused on the reason for a decision, the choice made, and the consequences.

Use decision records for architecture, conventions, data model, dependencies, product behavior, build setup, and other choices future contributors should preserve or understand. Tiny fixes, copy edits, and purely mechanical cleanup usually do not need a decision record.

## Merged Active Decision State

When decision records overlap, follow explicit supersession first and then prefer the later accepted record.

- **Decision log:** Keep decisions in this directory. Add or supersede records for meaningful long-term architecture, data model, dependency, product behavior, build setup, or convention changes.
- **Timed routines:** Exact-time routine occurrences become missed assumptions after their scheduled day instead of staying overdue across later days. Unresolved assumptions stay visible until resolved as done, missed, or canceled. Time-range routines reuse the same missed-resolution model, with the range start stored as the occurrence timestamp.
- **Routine recurrence storage:** Recurrence metadata is stored in typed SwiftData columns. Legacy recurrence JSON remains only as a migration source and should not be used for new writes.
- **Outcome language and styling:** Timeline activity includes done, missed, and canceled outcomes. Canceled outcomes use neutral gray styling, missed stays distinct from red overdue styling, due/soon-due keeps orange, and overdue keeps red.
- **Planner timeline activity:** The planner can surface unplanned done, missed, and canceled timeline activity for a date. Automatic timeline blocks are derived, visually distinct from user-placed blocks, configurable from Settings > Calendar, and can be confirmed into persisted planner blocks without rewriting timeline history.
- **Planner live sessions:** Active focus sessions render as live derived planner blocks while running. Finished focus sessions remain focus history rather than becoming planner blocks unless a future decision changes that. Sleep sessions render as protected planner blocks and prevent overlapping planner placements.
- **macOS task interactions:** The custom macOS task list owns explicit arrow-key navigation through visible task rows. In the planner sidebar, single click selects and double click opens task details.
- **Sleep:** Sleep is an app-level `SleepSession` mode rather than a routine completion. Sleep and focus timers do not overlap. Active sleep gates the app until ended or undone, and sleep history participates in timeline, planner, stats, widgets, backup, import, and reset flows as dedicated sleep data.
- **Place check-ins:** Place check-ins are duration-based `PlaceCheckInSession` records. Starting a new place closes the prior active session, same-place check-ins update the active session, and sessions may store place snapshots, saved-place links, coordinates, and activity tags. Place sessions are timeline evidence distinct from planned blocks, sleep, and focus.
- **Map and day place review:** iPhone and Mac expose map-based check-in from the check-in dock. The map flow can request current location, use saved-place radii, record raw current-location sessions, show grouped history markers for coordinate-backed check-ins, and show a grouped Day history where place sessions can be reviewed, edited, or deleted. Saved-place list rows select and focus places; recording a saved-place check-in requires an explicit action control.
- **Mac Places:** The active Mac Places architecture is [0021](0021-keep-mac-places-in-home-split-shell.md), superseding the 0017-0020 presentation chain. Places stays inside the shared Home split-view shell: the sidebar keeps the shared mode strip and swaps task filters/list for place controls, saved places, and day timeline; the detail column renders the map.
- **Mac Home toolbar:** Global Home toolbar content belongs to the root split-view shell, not the sidebar column. Detail-specific controls may still be attached by detail views. The Home window uses full-size transparent titlebar with unified toolbar styling.
- **Liquid Glass UI:** Custom app cards, panels, chips, and floating controls use shared Liquid Glass surface modifiers with semantic tinting and material fallbacks. Standard system structures stay system-native, and custom opaque backgrounds behind macOS split-view chrome should be avoided.

## Open Questions

- `docs/routina-features-web.html` is older than the decision log entries for missed outcomes, sleep sessions, and place sessions. Should the public feature guide be updated to describe timeline activity as done, missed, canceled, sleep, and place/session history instead of only completed and canceled work?
- `docs/recurring-window-routines.md` proposes recurring-window and flexible-gap schedules, but no accepted decision record currently adopts that model. Should this be promoted into a numbered decision before implementation?
- [0021](0021-keep-mac-places-in-home-split-shell.md) says the `Details / Planner / Board / Places` picker stays in the detail-column header, while [0022](0022-own-mac-home-toolbar-at-split-shell.md) moves global Home toolbar content to the root split-view shell. Should the mode picker be treated as detail-header content or as global Home toolbar content?

## Records

| ID | Title | Status | Date |
| --- | --- | --- | --- |
| [0001](0001-maintain-project-decision-log.md) | Maintain a Project Decision Log | Accepted | 2026-05-08 |
| [0002](0002-exact-time-routines-miss-after-day.md) | Treat Exact-Time Routines as Missed After Their Scheduled Day | Accepted | 2026-05-08 |
| [0003](0003-resolve-exact-time-missed-assumptions.md) | Resolve Exact-Time Missed Assumptions as Done, Missed, or Canceled | Accepted | 2026-05-09 |
| [0004](0004-macos-task-list-keyboard-navigation.md) | Support Keyboard Navigation in the macOS Task List | Accepted | 2026-05-09 |
| [0005](0005-show-timeline-activity-in-day-planner.md) | Show Timeline Activity in the Day Planner | Accepted | 2026-05-09 |
| [0006](0006-make-planner-timeline-activity-configurable.md) | Make Planner Timeline Activity Configurable | Accepted | 2026-05-09 |
| [0007](0007-show-active-focus-timers-in-planner.md) | Show Active Focus Timers in the Planner | Accepted | 2026-05-09 |
| [0008](0008-confirm-timeline-activity-as-planner-block.md) | Confirm Timeline Activity as Planner Blocks | Accepted | 2026-05-09 |
| [0009](0009-support-routine-time-ranges.md) | Support Routine Time Ranges | Accepted | 2026-05-09 |
| [0010](0010-store-recurrence-rules-in-swiftdata-columns.md) | Store Recurrence Rules in SwiftData Columns | Accepted | 2026-05-09 |
| [0011](0011-open-planner-sidebar-tasks-with-double-click.md) | Open Planner Sidebar Tasks with Double Click | Accepted | 2026-05-09 |
| [0012](0012-model-sleep-as-app-level-session-mode.md) | Model Sleep as an App-Level Session Mode | Accepted | 2026-05-10 |
| [0013](0013-use-neutral-cancellation-styling.md) | Use Neutral Cancellation Styling | Accepted | 2026-05-10 |
| [0014](0014-model-place-check-ins-as-place-sessions.md) | Model Place Check-Ins as Place Sessions | Accepted | 2026-05-10 |
| [0015](0015-support-map-based-place-check-ins.md) | Support Map-Based Place Check-Ins | Accepted | 2026-05-10 |
| [0016](0016-show-place-check-ins-as-day-timeline.md) | Show Place Check-Ins as a Day Timeline | Accepted | 2026-05-10 |
| [0017](0017-show-mac-map-check-in-inline.md) | Show Mac Map Check-In Inline | Superseded | 2026-05-10 |
| [0018](0018-show-mac-map-check-in-in-detail-column.md) | Show Mac Map Check-In in the Detail Column | Superseded | 2026-05-10 |
| [0019](0019-show-mac-places-as-detail-mode.md) | Show Mac Places as a Detail Mode | Superseded | 2026-05-10 |
| [0020](0020-show-mac-places-as-workspace.md) | Show Mac Places as a Workspace | Superseded | 2026-05-10 |
| [0021](0021-keep-mac-places-in-home-split-shell.md) | Keep Mac Places in the Home Split Shell | Accepted | 2026-05-11 |
| [0022](0022-own-mac-home-toolbar-at-split-shell.md) | Own Mac Home Toolbar at the Split Shell | Accepted | 2026-05-11 |
| [0023](0023-edit-place-check-ins-from-day-timeline.md) | Edit Place Check-Ins from the Day Timeline | Accepted | 2026-05-11 |
| [0024](0024-adopt-liquid-glass-ui-surfaces.md) | Adopt Liquid Glass UI Surfaces | Accepted | 2026-05-12 |
| [0025](0025-show-place-check-in-history-markers-on-map.md) | Show Place Check-In History Markers on the Map | Accepted | 2026-05-12 |
| [0026](0026-require-explicit-saved-place-check-in-action.md) | Require an Explicit Saved-Place Check-In Action | Accepted | 2026-05-12 |
| [0027](0027-show-places-day-as-grouped-history.md) | Show Places Day as Grouped History | Accepted | 2026-05-12 |
