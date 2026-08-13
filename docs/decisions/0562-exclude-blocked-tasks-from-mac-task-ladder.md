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

The Mac Task Ladder excludes one-off tasks whose Todo state is `Blocked`, in
addition to paused, snoozed, completed, canceled, and archived tasks. Blocking
does not alter the ticket's data or placement in other task surfaces.

## Consequences

- Marking a ticket Blocked removes it from every Task Ladder metric until it is
  returned to Ready or In Progress.
- The Task Ladder's cached presentation filters the state before sectioning and
  sorting, so blocked tickets do not contribute to counts or ordering work.
