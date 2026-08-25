# 0247 — Give synchronized session status an action destination

Date: 2026-08-25

## Symptom

iOS Home could show an active Focus timer received from Mac, but tag and
unassigned timers had no tap destination and sprint Focus opened only a
read-only summary. The timer looked like an app-wide control while behaving as
status-only UI.

## Root Cause

The banner's action was modeled as an optional deep link. Task and sprint Focus
could sometimes supply a related entity, while tag and unassigned Focus could
not. Session controls were owned by those destination screens instead of by the
active session that the banner represented.

## Fix

The banner now always opens an active-Focus control sheet identified by the
exact session ID and kind. The sheet exposes the shared Pause/Resume, Finish,
and Abandon mutations for every Focus type, plus Open Task when task attribution
exists. Sprint actions were completed in the shared Focus service so their
semantics match task, tag, and unassigned Focus.

## Prevention Rule

When synchronized app-wide status is presented as an actionable surface, route
from the represented record identity to a complete control destination. Do not
make core controls depend on whether that record happens to have a related
screen or optional deep link.

## Regression Safeguard

- `Tests/Shared/ActiveFocusControlSourceTests.swift` requires the full banner
  action and all active-Focus controls.
- `Tests/Shared/FocusSessionSupportTests.swift` verifies sprint pause, resume,
  finish, and abandon behavior through the shared mutation API.
- `docs/scenarios/README.md` defines the iOS Home cross-device control contract.
