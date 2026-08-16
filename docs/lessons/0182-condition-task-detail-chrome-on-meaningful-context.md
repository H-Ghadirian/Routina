# 0182 — Condition task-detail chrome on meaningful context

Date: 2026-08-16

## Symptom

An ordinary iOS todo showed `Selected / Today`, placed Done after Calendar, and
wrapped the otherwise standalone Done button in an empty outlined card. The
screen communicated more structure than the current task state required.

## Root Cause

The mobile todo header and action section used fixed presentation slots. The
selected-date badge and action card rendered regardless of whether date or state
context differed from the default, so later progressive-disclosure improvements
could not remove their redundant visual weight.

## Fix

Today no longer receives selected-date chrome; a non-today target is explicitly
named `Viewing`. Todo completion precedes Calendar, and the outer action card is
used only when State, timing, or blocker context needs grouping. Related metadata
also uses adaptive wrapping and accessibility-sized controls instead of assuming
one fixed compact layout.

## Prevention Rule

Do not reserve a permanent badge, card, or row for default task-detail context.
Render context chrome only when it changes the meaning of an action or groups
additional controls, and verify the resulting hierarchy at ordinary and
accessibility text sizes.

## Regression Safeguard

`TaskDetailSharedViewSupportTests` protects conditional `Viewing` metadata and
the adaptive priority-control order. `TaskDetailPlatformActionParityTests`
protects completion-before-Calendar order, conditional action-card chrome,
toolbar identity, and explanatory option-count copy.

Related decision: [0594 — Simplify iOS Task Detail Scan and Action Hierarchy](../decisions/0594-simplify-ios-task-detail-scan-and-action-hierarchy.md).
