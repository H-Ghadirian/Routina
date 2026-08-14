# 0162 — Defer iOS Home refreshes during scrolling

Date: 2026-08-14

## Symptom

Home visibly hitched while scrolling on a physical iPhone using the production
Release app. A focused trace measured 10.624 seconds of Routina main-thread CPU
over 34.5 seconds, with 200–260 millisecond bursts repeating roughly every two
to three seconds during and after the gesture.

## Root Cause

CloudKit import and remote-change activity delivered coalesced
`.routineDidUpdate` notifications at a minimum spacing of two seconds. Active
iOS Home immediately converted every pulse into a full main-actor task load,
timeline-fallback derivation, state application, and display refresh. A second
Home observer also fetched every attachment row on each pulse. Unlike macOS,
iOS had no scroll-quiet gate around these notification-driven reloads.

The profiling workflow initially obscured validation because `xctrace` had
reached its recording time limit but had not finished saving the trace bundle.
The output was usable only after retaining the execution session and waiting
for `Output file saved` and a successful process exit.

## Fix

iOS Home now records real list offset changes, coalesces routine-update pulses,
and retains one pending refresh while the list is active. After 1.2 seconds of
scroll quiet, it performs one current task reload and attachment-ID fetch. The
inactive-tab boundary and immediate local mutation behavior remain unchanged.

The production profiling runbook now requires waiting for the actual
`xctrace` save completion rather than treating the time-limit message as a
finished trace.

## Prevention Rule

Never start full-model fetch, derivation, or attachment work from a persistence
notification while an unbounded iOS list is scrolling. Coalesce notifications,
retain one invalidation, and refresh after a measured quiet window without
discarding correctness updates.

Treat Instruments recording and trace saving as separate phases. Do not export
or inspect a trace until its recording process exits successfully after
reporting the saved output path.

## Regression Safeguard

`IOSScrollingPerformanceRegressionTests` verifies that Home records iOS scroll
activity, owns deferred refresh state, checks the scroll gate before reloading,
and does not keep a second direct `.routineDidUpdate` attachment observer.
[Decision 0567](../decisions/0567-defer-ios-home-refreshes-until-scrolling-is-quiet.md)
records the durable refresh boundary.

A post-fix physical-device Release trace detected 10 seconds of sustained Home
scrolling with zero samples in the complete Home task-load pipeline. The
equivalent detected-scroll window in the pre-fix trace contained 1.960 seconds
of that load work.
