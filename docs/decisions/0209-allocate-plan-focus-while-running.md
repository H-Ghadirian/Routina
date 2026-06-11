# 0209 Allocate Plan Focus While Running

Status: Accepted

Date: 2026-06-11

Refines: [0205 Run Plan Focus From Planner](0205-run-plan-focus-from-planner.md)

## Context

Plan focus originally required users to finish the timer before assigning the session to a planned task. That made attribution feel artificially delayed when the user already knew how the elapsed time should be split, and a single target could not represent sessions where one focus window covered several tasks from `Plan to do today`.

## Decision

Plan focus can be allocated while the timer is still running or after it is finished.

The Planner allocation surface accepts minute splits across multiple tasks currently in `Plan to do today`, including daily routines. The total allocation is capped by the focus time elapsed or recorded at the moment of allocation. Saving allocation updates task time spent for each selected task and creates task-colored planner evidence for the allocated minutes.

The underlying plan-focus `FocusSession` remains an unassigned session for focus history, widgets, shielding, and stats compatibility. Planner allocation blocks are the durable attribution evidence, so a completed plan-focus session with saved allocations no longer appears as pending allocation.

## Consequences

Users can attribute known work immediately without ending the timer, and one plan-focus window can fairly contribute time spent to several tasks.

Because allocation is stored as planner/task attribution rather than by changing the unassigned focus session into one task, future reporting should treat plan-focus allocation blocks as the source of multi-task attribution.
