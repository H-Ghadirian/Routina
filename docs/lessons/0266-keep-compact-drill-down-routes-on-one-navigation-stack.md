# 0266 — Keep compact drill-down routes on one navigation stack

Date: 2026-08-29

## Symptom

On iPhone, swiping Back from Task Ladder Group Details revealed the main Home
list underneath and completed the gesture at Home instead of returning to the
preceding Task Ladder list.

## Root Cause

Home unconditionally used `NavigationSplitView`. On a compact device SwiftUI
collapsed that sidebar/detail hierarchy, so Task Ladder occupied a replaceable
detail position rather than a durable level in a compact push stack. Group
Details could look pushed while fully presented, but the interactive transition
exposed the collapsed Home column beneath it.

## Fix

Home now owns one `NavigationStack` on compact iPhone and iPad layouts and keeps
its sidebar/detail split only on regular-width iPad. Task Ladder, Group Details,
and inner ladders therefore participate in one ordered push hierarchy. Compact
task rows use the existing selection binding as their destination trigger so row
taps, Focus controls, and deep links continue to open Task Details, while regular
iPad task selection keeps its split-view behavior.

## Prevention Rule

When a compact journey drills down through a workspace and then into that
workspace's descendants, every level must be owned by the same native navigation
stack. Do not rely on compact collapse of a split view to model an ordered push
history. Preserve state-driven and deep-linked destinations explicitly when
adapting a selection-based split layout to a compact stack.

## Regression Safeguard

`IOSHomeWorkspaceNavigationSourceTests.compactHomeKeepsTaskLadderAndGroupDetailsOnOneNavigationStack`
guards the adaptive Home container, compact task routing, and absence of a nested
Task Ladder stack. The iOS Home workspace scenario also requires interactive Back
from Group Details to reveal and return to the preceding Task Ladder list.
