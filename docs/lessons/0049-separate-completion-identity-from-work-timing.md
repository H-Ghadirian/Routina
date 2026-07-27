# 0049 — Separate completion identity from work timing

Date: 2026-07-27

## Symptom

The Mac `Done this day` editor required one start time even when a task's total
duration came from several sessions spread across the day.

## Root Cause

The editor treated the completion timestamp as both the recorded occurrence's
identity and proof of one continuous work interval. Those are separate facts:
a completion needs a date-bearing identity even when its work has no single
start and end.

## Fix

Completion logs now keep an optional specific-work-time marker. Duration-only
saves preserve the occurrence timestamp and update the daily total, while
specific-time saves continue to derive the completion timestamp from start plus
duration. Calendar List and the editor present the stored distinction.

## Prevention Rule

Do not overload an occurrence timestamp to imply continuous work timing.
Whenever duration may be aggregated across sessions, store and present whether
the interval is specific separately from the timestamp used for identity.

## Regression Safeguard

`DayPlanPlannerStateTests` covers timestamp preservation, exact-log updates, and
duration-only Calendar List presentation. Backup mapping and persistence
coverage verify that the timing marker survives export and restore.
