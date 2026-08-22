# 0224 — Release embedded detail chrome before changing workspace layout

Date: 2026-08-22

## Symptom

Opening Task Details inside the Mac Backlog added an unexpected native title
strip with the task emoji above Routina's shared toolbar. Switching from that
state to Planner could then crash inside AppKit split-view constraint updates.

## Root Cause

The full Task Detail registered its principal native toolbar item even though it
was embedded inside a workspace that already owned the main window chrome. The
same transition removed the embedded detail and replaced Backlog's `HSplitView`
with Planner's navigation split hierarchy in one layout update, leaving AppKit
to reconcile departing toolbar and split-view ownership simultaneously.

## Fix

Backlog and Task Ladder now suppress Task Detail's native principal toolbar
title when embedding it. Leaving Backlog with a detail open first clears the
embedded selection and detail state, then changes the main workspace on the next
main-queue turn.

## Prevention Rule

An embedded detail must not register window-level navigation or toolbar chrome
owned by its host workspace. Before replacing one AppKit-backed split hierarchy
with another, remove any selected embedded detail and allow that state change to
settle before switching the parent layout.

## Regression Safeguard

`BacklogFeatureTests.deactivatingWorkspaceClearsEmbeddedTaskDetailBeforeLayoutChanges`
protects reducer cleanup. `MacWorkspaceNavigationSourceTests` verifies that
embedded details suppress principal toolbar titles and that Backlog departure is
staged before the workspace mode change. The matching user flow is recorded in
`docs/scenarios/README.md`.
