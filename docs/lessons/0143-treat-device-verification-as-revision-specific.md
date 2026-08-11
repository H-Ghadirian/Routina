# 0143 — Treat device verification as revision-specific

Date: 2026-08-11

## Symptom

A Release app was successfully installed on a physical iPhone, but a later
source correction needed a new build. That final build was blocked by unrelated
untracked Backlog work, leaving only a partial app bundle without an executable
or `Info.plist`.

## Root Cause

The earlier install was at risk of being treated as verification for source it
did not contain. The final build state was not first gated on the exact
worktree, and a partial app directory looked superficially like a product.

## Fix

The production-device runbook now records the worktree state before the final
build, requires an executable and `Info.plist` before install, and makes every
post-build source or worktree change require a new build, install, and launch.

## Prevention Rule

Never claim final real-device verification from an earlier build. Preserve
unrelated modified or untracked work; resolve its compiler failures with the
owner or explicit permission rather than changing it incidentally.

## Regression Safeguard

The [iOS Production Device Profiling](../ios-production-device-profiling.md)
runbook and Decision
[0547](../decisions/0547-verify-final-ios-release-build-state.md) define the
required final-build checklist.
