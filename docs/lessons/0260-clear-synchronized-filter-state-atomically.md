# 0260 — Clear synchronized filter state atomically

Date: 2026-08-28

## Symptom

After applying a filter in Planner's Shared scope, the clear action above the
filtered Timeline appeared not to work. The filter remained active and the
Timeline stayed narrowed.

## Root Cause

Shared filters are intentionally mirrored in Task List and Timeline state so
both surfaces can use them. Timeline's clear action dispatched a sequence of
independent mutations that reset Timeline-owned fields and only some of the
Task List-side Shared fields. Shared-state reconciliation then treated the
uncleared mirror as authoritative and restored the values that had just been
cleared.

## Fix

Timeline clear is now one reducer action that resets Timeline-owned filters and
both copies of every Shared filter in a single state mutation and persistence
write. Task List-only filters remain unchanged.

## Prevention Rule

When state is mirrored for cross-surface synchronization, reset every copy in
one reducer mutation. Do not clear mirrors through separately observable
actions that allow reconciliation to restore a partially cleared value.

## Regression Safeguard

`Tests/Shared/HomeFilterEditorTests.swift` verifies the Shared/Timeline reset
boundary, `Tests/macOS/HomeFeatureTests.swift` verifies atomic reducer state and
persistence, and `Tests/Shared/MacWorkspaceNavigationSourceTests.swift` keeps
the Timeline notice wired to the atomic action. The Planner Timeline scenario
also requires Shared and Timeline filters to clear together while Task
List-only filters survive.
