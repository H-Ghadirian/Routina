# 0349 Preserve Interval Anchor on Frequency Edits

Status: Accepted

Date: 2026-07-07

Refines: [0178 Make Recurrence Availability Independent](0178-make-recurrence-availability-independent.md)

## Context

Interval routines use a rolling schedule anchor to decide the next due day. Completion normally moves that anchor to the completion date. Editing a routine's interval frequency previously reset the anchor to the edit timestamp whenever the recurrence rule changed.

That made a routine completed in the past jump forward from the edit day instead of recalculating the new interval from the existing completion-based anchor. For example, a routine completed on June 25 and edited from every 10 days to every 12 days on July 7 could incorrectly show July 19 as the next due date.

## Decision

When an existing non-todo routine changes from one interval recurrence to another interval recurrence, the edit flow preserves the routine's existing rolling schedule anchor instead of replacing it with the edit timestamp.

New routines or edits that switch into or out of calendar recurrence can still use the edit timestamp as the new scheduling anchor because calendar patterns have separate next-occurrence semantics.

## Consequences

Changing an interval frequency applies the new cadence to the current rolling history. Existing completion history remains meaningful, and routines that should be due immediately after a frequency edit do not jump to a future cycle just because the edit happened today.
