# 0248 — Keep workspace presentation state above conditional views

Date: 2026-08-26

## Symptom

Collapsed Backlog super sections and subsections expanded again after the person switched to Planner, Task Ladder, or another main-window workspace and returned.

## Root Cause

Backlog kept both collapsed-ID sets as local `@State` on `BacklogMacView`. The main window conditionally removes that view when another workspace becomes active, so SwiftUI destroyed the disclosure choices even though the long-lived `BacklogFeature.State` remained available.

## Fix

The Backlog reducer now owns the super-section and subsection collapsed-ID sets and handles their toggle actions. Recreating the conditional Backlog view reads the existing feature state, while search continues to reveal matches without mutating the stored choices.

## Prevention Rule

Presentation state that must survive switching away from a conditionally rendered workspace belongs to the workspace's long-lived feature or presentation model, not to the conditional root view's local state.

## Regression Safeguard

`BacklogFeatureTests.workspaceSwitchPreservesBacklogDisclosureChoices` verifies that workspace deactivation retains both levels, and `searchExpansionDoesNotMutateBacklogDisclosureChoices` protects temporary search expansion. The matching flow is recorded in `docs/scenarios/README.md`.
