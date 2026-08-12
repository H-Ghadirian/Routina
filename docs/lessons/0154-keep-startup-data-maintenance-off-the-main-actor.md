# 0154 — Keep startup data maintenance off the main actor

Date: 2026-08-13

## Symptom

The iOS Debug performance profile recorded 1.14-second and 831-millisecond
main-thread stalls directly after launch, making the first app interaction
feel delayed.

## Root Cause

Persistence migrations were scheduled and invoked directly, so they ran
twice. The first Home snapshot also ran complete-history deduplication, log
backfill, and orphan cleanup on the main actor.

## Fix

A single utility-priority SwiftData model actor now performs the startup
migrations and integrity passes with a private context. The first Home load
fetches only its visible snapshot; a single normal update follows only when
background maintenance changed data.

## Prevention Rule

Do not add full-store migration, repair, deduplication, or cleanup work to
scene activation or a first-render reducer effect on the main actor. Route it
through the shared startup maintenance worker and publish one coalesced update
after it completes.

## Regression Safeguard

`IOSScrollingPerformanceRegressionTests.activeIOSSurfaceOwnsRefreshWorkAndStartupMaintenanceStaysOffMainActor`
and `PerformanceRegressionTests.testMacHomeDefersWholeHistoryMaintenanceOffTheMainActor`
guard the detached `@ModelActor` worker and the lightweight initial Home load.
Decision [0559](../decisions/0559-run-startup-data-maintenance-off-the-main-actor.md)
records the durable behavior.
