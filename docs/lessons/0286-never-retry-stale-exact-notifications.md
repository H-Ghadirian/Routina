# 0286 — Never Retry Stale Exact Notifications

Date: 2026-09-03

## Symptom

An unresolved biweekly meeting scheduled for Tuesday at 09:45 remained overdue
days later, while its pending notification was repeatedly rebuilt one minute
in the future and alerted again.

## Root Cause

Single-time structured recurrences without an outer range were excluded from
exact-occurrence lifecycle handling. The notification scheduler then applied a
generic `now + 60 seconds` fallback to the stale explicit trigger, creating a
new request every time reconciliation ran.

## Fix

Single-occurrence structured days now use exact missed-occurrence semantics,
rolling notification lists exclude past dates, and stale exact triggers are
dropped instead of rescheduled. Queued occurrence metadata is also carried
through notification quick actions so Done resolves the alert's occurrence.

## Prevention Rule

Never repair a stale explicit notification timestamp by moving it relative to
the current clock. First classify the source occurrence correctly, then either
schedule a genuinely future occurrence or schedule nothing.

## Regression Safeguard

`RoutineDateMathTests` covers the missed and next dates for a single-time
biweekly structured recurrence. `NotificationCoordinatorTests` covers its
future-only rolling payload, rejects a stale exact trigger, verifies occurrence
metadata recovery, and keeps past rolling dates out of the pending queue.

See [Decision 0714](../decisions/0714-treat-single-time-structured-routines-as-occurrences.md)
and the notification regression scenario in
[`docs/scenarios/README.md`](../scenarios/README.md).
