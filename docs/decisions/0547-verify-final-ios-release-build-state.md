# 0547: Verify the Final iOS Release Build State

## Status

Accepted

## Date

2026-08-11

## Refines

- [0542: Use Validated Release Device Traces for iOS Performance Investigations](0542-use-validated-release-device-traces-for-ios-performance-investigations.md)

## Context

A physical-device Release build may succeed, be installed, and then become
stale after a later code correction. Separately, untracked work owned by
another change can enter the shared worktree and fail the production compiler.
A partial `.app` directory can remain after that failure, even though it lacks
the executable and `Info.plist` needed for installation.

## Decision

Final iOS device verification is tied to the exact recorded worktree state.
Before building, record the short Git status and resolve unexpected
target-affecting changes with their owner. After every subsequent source,
configuration, dependency, or worktree change, repeat build validation,
installation, and launch. A build only qualifies when its app bundle contains
the expected bundle identifier, executable, and matching dSYM.

## Consequences

- A prior installed app never stands in for verification of newer source.
- Shared-worktree changes are preserved rather than silently edited or removed
  to force a build.
- Incomplete build products are recognized as failures before device install or
  performance conclusions.
