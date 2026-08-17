# 0192 — Keep recorded Done rows on completion time

Date: 2026-08-17

## Symptom

A completed task in Mac Calendar `List` showed its retained Planner block time,
while the adjacent `Done this day` editor showed the later recorded work time.

## Root Cause

The day-task presentation correctly reclassified a Planner-backed task into
`Dones` and attached its exact completion occurrence, but it kept the row's
placement from the planned block. The detail editor independently derived its
start and duration from the attached completion, so the two review surfaces
described different time sources.

## Fix

Recorded completion rows and the adjacent editor now share one work-timing
derivation from the attached completion timestamp, duration, and specific-time
marker. Rows apply that timing before they are sorted. The distinct Planner
placement remains unchanged for Calendar `Schedule`.

## Prevention Rule

Once a Planner row is presented as recorded completion evidence, every displayed
work-time field and its sort position must come from the selected completion
occurrence, not from retained planning metadata.

## Regression Safeguard

The Calendar List completion scenarios now require the row and editor to agree
when a different Planner block remains. `DayPlanPlannerStateTests` verifies that
a Planner-backed Done row uses completion minus duration for a specific-time
placement, uses duration-only placement without a specific time, and still
carries the exact editable occurrence.
