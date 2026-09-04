# 0735 — Compose Main Task List From Shared Task-Row Semantics

## Status

Accepted

## Date

2026-09-04

## Refines

- [0038 — Configure Home Task Row Fields](0038-configure-home-task-row-fields.md)
- [0418 — Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0593 — Show Relationship Blocking in Home Task Rows](0593-show-relationship-blocking-in-home-task-rows.md)
- [0734 — Share Task-Row Semantics Without Flattening Workspace Context](0734-share-task-row-semantics-without-flattening-workspace-context.md)

## Context

Decision 0734 gave Backlog and Task Ladder one shared semantic task-row
presentation, but Main Task List still built the same identity and stable
lifecycle facts independently inside its richer Home display. The visible Home
row was already more detailed for good reasons: it presents current-occurrence,
location-availability, planning, completion, and action context that would be
misleading or distracting in Backlog and Task Ladder.

Keeping the richer display separate must not leave a second definition of the
task's normalized name, icon, task type, image and pin state, saved color, Tags,
Flags, or stable lifecycle status. That would allow the three primary task-row
surfaces to drift again.

## Decision

Main Task List composes the same immutable `TaskRowSemanticPresentation` used by
Backlog and Task Ladder while building its existing cached
`HomeRoutineDisplay`. The Home snapshot passes the same Flag rules, reference
date, calendar, and relationship-blocked result into the semantic builder. Its
normalized name and emoji, image and pin state, color, Tags, and Flags originate
from that shared value.

Main Task List uses the shared status wording, icon, and tone for stable
lifecycle meaning, including Paused, Not today, relationship-derived Blocked,
and one-time To Do, In Progress, Done, or Canceled states. A one-time task's step
position remains separate progress metadata instead of replacing its lifecycle
status.

Home-specific presentation remains layered on top. Location availability,
assumed completion, repeating occurrence progress, due pressure, planning
labels, Goals, completion actions, row numbering, and section membership keep
their established Main Task List behavior. Active repeating routines may
therefore show occurrence-specific status context that Backlog or Task Ladder
does not need.

The semantic value is built once at the same refresh boundary as the complete
Home display. SwiftUI rows and metadata presenters only read the cached value;
they do not recreate it while scrolling. Main Task List search results and the
Planner task sidebar inherit it because they consume the same Home displays.

## Consequences

- Main Task List, Backlog, and Task Ladder now have one source for task identity
  and stable lifecycle meaning on iPhone and Mac.
- Main Task List retains the richer context needed to decide and act instead of
  being reduced to Backlog or Task Ladder's row vocabulary.
- In-progress one-time tasks keep `In Progress` as their status while step
  position remains independently visible when Progress is enabled.
- Relationship blocking enters the detailed Home display and shared semantic
  value together, preventing contradictory cached states.
- Cross-surface semantic work stays outside scrolling render paths.
