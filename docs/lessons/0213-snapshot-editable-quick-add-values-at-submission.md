# 0213 — Snapshot editable Quick Add values at submission

Date: 2026-08-20

## Symptom

After webpage metadata proposed a title, a person could edit that title and press Enter yet find a different title on the created task. A reminder selected in the same Quick Add preview could likewise be absent from the saved task and its Edit or Task Details surfaces.

## Root Cause

The submit handler preserved the parser draft but still read the editable title and reminder controls separately from live Home state. Focus, menu, and render updates could therefore make the values used by asynchronous creation differ from the preview the person submitted.

## Fix

The attached preview now creates one immutable submission value containing its currently displayed title and reminder timestamp. The creation path passes that submission directly to the shared persistence service and independently reparses the raw query only as a fallback for submissions made from the toolbar field itself.

## Prevention Rule

Interactive previews must submit one immutable value containing every user-editable and derived field shown at the moment of confirmation. Do not reconstruct part of a submitted form from ambient view state after the submit event.

## Regression Safeguard

`HomeMacToolbarQuickAddSubmissionTests` verifies that the submission preserves an edited YouTube title and resolves a selected reminder from the active exact-availability draft. The Mac source regression test requires the same submission object to provide both overrides to the shared save service, whose persistence tests verify the stored `RoutineTask` fields.
