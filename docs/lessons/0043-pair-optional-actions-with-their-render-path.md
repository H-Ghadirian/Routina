# 0043 — Pair Optional Actions With Their Render Path

Date: 2026-07-26

## Symptom

In full Mac Task Details, clicking `Time` for an internal record-shaped task
removed the action without revealing any time controls.

## Root Cause

The optional-action policy allowed both one-time Todos and internal records to
reveal task-level time. The corresponding Effort header box was rendered only
by the Todo header path, while records followed the routine header path after
Tracking was retired as a user-facing type.

## Fix

Mac Task Detail now derives the Time action and Effort header-box placement from
one presentation policy. A record keeps the action until time is visible and
the routine header renders the box after reveal. Todo estimate and story-point
metadata continue to reveal the combined Effort box automatically.

## Prevention Rule

Every progressive-disclosure action must share one presentation policy with
the view that consumes its revealed state. When a model type is presented
through another type's layout, audit both action eligibility and the selected
render branch.

## Regression Safeguard

`TaskDetailMacTimeControlPresentationTests` covers hidden and revealed internal
records, records with estimates, one-time Todo effort metadata, and normal
routines that must not expose task-level time.
