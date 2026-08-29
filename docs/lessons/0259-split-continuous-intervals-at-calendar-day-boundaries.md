# 0259 — Split continuous intervals at calendar-day boundaries

Date: 2026-08-28

## Symptom

An overnight count-up Focus session had the correct start, finish, and duration
in Timeline, but Calendar showed only the portion from its start to midnight on
the first day. The occupied hours after midnight were absent.

## Root Cause

Focus history stores one continuous interval, while each Planner block belongs
to one day and cannot extend beyond that day's final minute. The Focus-to-Planner
projection created only one block from the full interval; the block initializer
correctly clamped it to the first day, but no continuation block was created for
the following day.

## Fix

Count-up task and tag Focus projections now split each uninterrupted segment at
local calendar-day boundaries and assign deterministic identities to the
continuation blocks. The existing lifecycle and data-revision reconciliation
uses the same projection, so it adds missing continuations to previously stored
overnight sessions and becomes a no-op after the repaired evidence is current.

## Prevention Rule

Whenever a continuous time interval is projected into records keyed by one
calendar day, intersect it with every occupied local-day window. Do not rely on
a day-bounded model's clamping behavior to represent the complete interval.

## Regression Safeguard

The Overnight Focus scenario requires one complete Timeline session and
day-bounded Calendar evidence on every occupied date.
`Tests/Shared/DayPlanPlannerStateTests.swift` covers both the normal finish path
and repair of an older first-day-only block, including idempotent repeated
reconciliation.

Follow-up: [0264](0264-bucket-focus-by-active-intervals-not-terminal-actions.md)
extends the day-boundary rule to Timeline and Stats and replaces the earlier
single-row Timeline presentation with daily active-time portions.
