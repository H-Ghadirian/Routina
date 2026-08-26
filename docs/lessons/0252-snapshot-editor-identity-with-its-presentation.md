# 0252 — Snapshot editor identity with its presentation

Date: 2026-08-26

## Symptom

The first edit of an existing Task Ladder container group showed an empty Name
field. Changing only a metric left Save disabled because the editor incorrectly
treated the existing group as unnamed.

## Root Cause

The Task Ladder view stored the group ID and the Boolean sheet presentation in
separate SwiftUI state. The Boolean-backed sheet could initialize its local
group draft before the ID update was visible, so the draft started as a new
empty group even though the sheet's later input and title represented an edit.

## Fix

The entry point now creates one identifiable presentation value containing the
complete existing group snapshot and presents the editor with an item-backed
sheet. The editor's name, emoji, and metrics therefore initialize from the same
group value before the sheet appears.

## Prevention Rule

When an editor's validation depends on the identity being edited, include that
identity and its initial draft data in the presentation item. Do not present
with a separate Boolean while independently changing the editor's lookup key.

## Regression Safeguard

`TaskRankingPresentationTests.taskLadderGroupEditorSnapshotsExistingGroupBeforePresentation`
requires an item-backed group-editor payload and rejects the former Boolean and
separate-ID state. The Mac Task Ladder scenario also requires a first edit to
retain the group's identity and permit a metric-only save.
