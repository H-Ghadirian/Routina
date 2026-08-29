# 0692: Control When Due Tasks Enter Task Ladder

## Status

Accepted

## Date

2026-08-29

## Revises

- [0561: Add a Separate Mac Task Ranking Ladder](0561-add-separate-mac-task-ranking-ladder.md)

## Refines

- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0438: Allow Early Completion of Untimed Scheduled Routines](0438-allow-early-completion-of-untimed-scheduled-routines.md)
- [0562: Exclude Blocked Tasks from the Mac Task Ladder](0562-exclude-blocked-tasks-from-mac-task-ladder.md)
- [0570: Exclude Flagged Tasks from the Mac Task Ladder](0570-exclude-flagged-tasks-from-mac-task-ladder.md)
- [0634: Unify Mac Workspace Search and Creation](0634-unify-mac-workspace-search-and-creation.md)
- [0649: Give Each Task Ladder Metric an Independent Time Rule](0649-give-each-task-ladder-metric-an-independent-time-rule.md)

## Context

A task can be possible to complete long before its due date while still being
irrelevant to the person's current comparison. For example, a five-minute rent
routine due near the end of the month, or a one-time application with a distant
deadline, can stay near the top of the Estimated time ladder too early.

Lowering Importance, Urgency, or Pressure does not solve this when the person
views another metric. `Hide from Task Ladder` is a persistent manual exclusion,
and Pause Until changes the task's broader lifecycle. Neither expresses an
attention window relative to the task's next concrete due boundary.

The due date remains the last acceptable completion date rather than a universal
start date. Therefore this need must not revoke the existing ability to complete
an untimed scheduled routine early.

## Decision

- Any task with a concrete due boundary can choose when it enters Task Ladder: `Throughout`, a chosen number of days before due, or `On due date`. Supported boundaries are a one-time task's deadline and a repeating Due routine's next active interval or calendar occurrence.
- `Throughout` remains the default for existing and newly created tasks. A due date alone does not silently hide a task.
- The entry window applies to Task Ladder membership across every metric, including Estimated time. It is independent from `Changes over time`, which continues to derive only the task's effective Importance, Urgency, and Pressure after the task belongs in the Ladder.
- Before the configured entry boundary, normal Ladder sections and counts omit the task. Explicit Task Ladder search still returns a matching task under `Outside Task Ladder` and explains when it will enter.
- Crossing a local calendar-day boundary rebuilds an open cached Ladder snapshot when any loaded task has a non-default entry window, regardless of the selected metric or Base/Now mode. Scrolling rows consume the stable snapshot and perform no full-catalog derivation.
- Add Task and Edit Task expose the entry window beside Task Ladder values whenever the task has a supported due boundary. Task Details summarizes a non-default choice. A repeating routine's before-due window is bounded to its After done recurrence interval when that interval has a fixed number of days; a one-time deadline has no recurrence cap.
- The choice changes no lifecycle, completion, notification, Home, Backlog, Planner, Calendar, Timeline, or Stats behavior. In particular, an untimed scheduled occurrence remains completable early. A future need to prohibit completion before an availability boundary requires a separate recurring-availability decision.
- The setting shares the existing version-tolerant Task Ladder JSON storage field with temporal value rules. The compatibility payload keeps the former top-level metric-policy keys and adds entry timing, so legacy payloads continue to decode in the new app and older app versions can still read temporal rules from new payloads. Sync, sharing, detached copies, and backup mappings continue to carry the raw field.
- One-time tasks without a deadline, Gentle routines, and cadence-free routines normalize to `Throughout` because they have no due boundary for the rule. A supported task whose due date cannot currently be derived stays visible rather than becoming permanently inaccessible.

## Consequences

- Short future work no longer needs to compete in Task Ladder merely because it has a duration estimate.
- People can choose a narrow attention window without losing search recovery or early-completion freedom.
- Existing one-time and repeating tasks preserve their current Ladder membership until a person deliberately changes the new control.
- Entry timing and ranking timing remain separate concepts, so changing one does not silently alter the other.
