# 0539: Offer iOS Task Creation From Home Empty States

## Status

Accepted

## Date

2026-08-11

## Context

iOS Home’s genuinely empty state was an important place to begin task capture,
but its action was not labelled consistently with the global New affordance.
More importantly, entering a search that produced no results left the person
without an in-context way to turn that intent into a task. Requiring them to
leave search and start again discards the title they just entered.

Creation must not appear solely because another Home filter hides a known
matching task. That would suggest duplicates instead of helping the person
recover their filtered result.

## Decision

A fully loaded iOS Home list with no tasks shows `Add New Task`, opening the
shared Smart Add flow.

When a non-empty Home search produces no known task match, its no-results state
also shows `Create Task`. It opens the same Smart Add flow and pre-fills the
input with the trimmed search text. A known matching task, including one hidden
by the current filters, suppresses the create action.

## Consequences

- Empty Home makes the next useful action clear without relying on the global
  New tab.
- Search can become task capture without retyping the intended title.
- Existing matching tasks remain a search/filter recovery problem, rather than
  a reason to create a likely duplicate.
