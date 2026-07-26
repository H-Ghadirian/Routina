# 0433 — Identify Subdaily History by Scheduled Occurrence

Status: Accepted

Date: 2026-07-26

Refines: [0412 Add Advanced Recurrence Beside Simple](0412-add-advanced-recurrence-beside-simple.md), [0432 Compose Fixed Recurrence With Availability Windows](0432-compose-fixed-recurrence-with-availability-windows.md)

## Context

Advanced recurrence already stored the scheduled occurrence timestamp in completion logs, which allowed two hourly completions on one day. Resolution behavior was nevertheless split across several local rules. Some completion and deduplication paths compared timestamps, while missed, canceled, optimistic Home state, and Task Detail paths still compared calendar days. One resolution could therefore acknowledge, replace, or remove a sibling occurrence.

That mixed contract also prevented a daily structured schedule with several explicit occurrence times from composing with one shared availability range, even though the recurrence and range were both losslessly stored.

## Decision

`RoutineLog.timestamp` is the occurrence identity for a recurrence that can produce more than one occurrence per calendar day. Completion, fulfillment, missed, canceled, deduplication, optimistic state, and Task Detail resolution comparisons use that scheduled timestamp with a one-second tolerance.

Single-occurrence cadence and existing compact recurrence retain calendar-day resolution. This preserves the meaning of existing history without a schema migration. Cadence-free reusable tasks also keep their existing timestamp-scoped log behavior.

A fixed daily structured recurrence with several explicit occurrence times may compose with one outer availability range:

- The structured occurrence timestamps remain the distinct identities.
- The outer range is one shared daily actionability boundary.
- Each unresolved scheduled occurrence closes at the range end and can be resolved independently.
- Notifications retain the scheduled occurrence times.
- A scheduled Planner range represents the shared outer range once on that date.

Hourly recurrence continues to reject a separate outer range. Hourly recurrence already owns continuous-versus-daily-window generation, so accepting another range would create two competing authorities. That restriction is no longer caused by log identity and should be removed only by making one window module canonical.

Task Detail's calendar remains a day-level navigation surface. Its primary action targets the next due scheduled occurrence, and undo removes the latest resolved timestamp on that selected day. History entries remain individually removable.

## Consequences

- Completing, missing, or canceling the 08:00 occurrence no longer resolves the 20:00 occurrence.
- Same-day subdaily logs survive local cleanup and CloudKit's existing timestamp-keyed merge.
- Existing single-occurrence and legacy day-based history do not require data migration.
- Multiple explicit daily times can now use Available window or Time block.
- A future occurrence picker can make every same-day occurrence directly selectable in Task Detail without changing storage again.
