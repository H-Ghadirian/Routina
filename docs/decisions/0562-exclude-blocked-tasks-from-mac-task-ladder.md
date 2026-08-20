# 0562: Exclude Blocked Tasks from the Mac Task Ladder

## Status

Accepted

## Date

2026-08-13

## Context

The Task Ladder is a workspace for ordering work a person can act on now.
Blocked one-off tickets remain active records, but cannot currently advance.
Showing them alongside actionable work obscures the ladder's immediate ranking
purpose.

## Decision

The Mac Task Ladder excludes one-off tasks whose stored or effective Todo state
is `Blocked`, in addition to paused, snoozed, completed, canceled, and archived
tasks. An effective `Blocked` state can come from an unresolved confirmed
`Blocked by` relationship while the stored task state remains Ready or In
Progress. Blocking does not alter the ticket's data or placement in other task
surfaces.

## Consequences

- Marking a ticket Blocked, or leaving it behind an unresolved confirmed
  prerequisite, removes it from every Task Ladder metric until it becomes
  actionable again.
- The Task Ladder's cached presentation resolves relationship blocking with
  loaded completion history and filters the effective state before sectioning
  and sorting, so blocked tickets do not contribute to counts or ordering work.
