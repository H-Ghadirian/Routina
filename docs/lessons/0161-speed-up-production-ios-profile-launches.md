# 0161 — Keep production iOS profiling setup warm but disposable

Date: 2026-08-14

## Symptom

Launching the production iOS app on a physical device for profiling took about
12 minutes before the person could begin reproducing performance problems.

## Root Cause

The profiling build correctly used fresh isolated Derived Data, but that also
put package checkout and artifact setup inside the disposable session folder.
Xcode therefore performed a cold package and optimized Release build,
including the then-bundled Watch extension. An initial restricted invocation failed on
Xcode cache permissions, and the command wrapper returned while the real
`xcodebuild` process was still active, leading to premature product checks and
manual polling.

Using a separate shared `-clonedSourcePackagesDirPath` was not a safe immediate
shortcut: Routina's Crashlytics upload phase currently expects Firebase's run
script under the session Derived Data's `SourcePackages` directory.

## Fix

The physical-device profiling runbook now uses a persistent package-support
cache through `-packageCachePath`, disables speculative dependency updates,
requires the first Xcode invocation to have the access it needs, waits for the
actual build process, and proceeds directly through validation, installation,
launch, and numeric-PID selection. It also makes one validated build serve all
scenario traces in an unchanged-worktree profiling session.

The app product, dSYM, Derived Data, traces, and exports remain isolated and
are still removed when the session ends.

## Prevention Rule

Keep production profiling outputs fresh and disposable while retaining only a
non-result package download/repository cache. Never trade exact Release-build
identity, matching symbols, or mandatory trace cleanup for a faster launch.
Do not introduce a shared package checkout path until every build phase that
assumes Derived Data-local `SourcePackages` has been updated and verified.

## Regression Safeguard

The [iOS Production Device Profiling](../ios-production-device-profiling.md)
runbook records the supported cache flags, the Crashlytics checkout constraint,
the actual-process wait requirement, the same-build reuse boundary, and the
mandatory cleanup distinction. [Decision 0566](../decisions/0566-keep-production-ios-profiling-setup-warm-but-disposable.md)
makes those rules durable. `-showBuildTimingSummary` keeps future launch delays
attributable to package setup, compilation, signing, or installation rather
than guesswork.
