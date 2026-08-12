# 0555: Preserve the Previous Debug Performance Run

## Status

Accepted

## Date

2026-08-12

## Refines

- [0553: Record Debug Performance Symptoms for Support](0553-record-debug-performance-symptoms-for-support.md)
- [0554: Correlate Debug Stalls With Safe Interaction Trails](0554-correlate-debug-stalls-with-safe-interaction-trails.md)

## Context

The Debug profiler writes its current session periodically and atomically, so
an abrupt crash usually leaves a valid report containing all but the final few
seconds. The original single-file design immediately replaced that report when
the app next launched. A person therefore could not reopen Routina and use its
native share action to hand off the interrupted session.

iOS does not reliably distinguish every crash, operating-system termination,
and force-quit at the next launch. Calling the retained file a crash report
would overstate what the app knows, and this lightweight profile does not
contain a fatal exception or crash call stack.

## Decision

Before a Debug launch starts writing its new current profile, Routina atomically
copies the existing current profile to one fixed previous-run file. Support &
About offers separate actions for sharing the current and previous runs whenever
those files exist.

The app retains exactly one previous run. A later launch replaces it with the
run that was current immediately before that launch. The UI calls it `Previous
Run` rather than `Crash` because it may represent a normal exit, force-quit,
operating-system termination, or crash.

## Consequences

- After a crash or force-quit, the person can reopen Routina once and share the
  most recently flushed interrupted profile from inside the app.
- The person should share the previous run before launching Routina again,
  because the following launch rotates the files again.
- A crash may omit roughly the final five seconds of periodic resource samples,
  and source-level crash diagnosis still requires an Apple crash report or
  symbolicated trace.
- Retention stays bounded to two privacy-safe JSON files: the current run and
  one previous run.
