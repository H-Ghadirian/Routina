# 0100 — Keep task-detail comment editor bindings live

Date: 2026-08-07

## Symptom

Typing in the middle of a Task Detail comment placed only the first character at the insertion point, then moved the cursor to the end for the remaining text.

## Root Cause

The shared comments view rebuilt each editor binding from a captured draft string. After a reducer update, the editor briefly read that stale value and AppKit reset its selection to the end of the text.

## Fix

Task Detail now passes live reducer-backed bindings for new and edited comment drafts directly to the shared formatted text editor on macOS and iOS.

## Prevention Rule

Any continuously edited text control must receive a binding whose getter reads current state; do not adapt an immutable render-time string into a text-editor binding.

## Regression Safeguard

`Tests/Shared/TaskDetailCommentsTests.swift` asserts that the comments view uses direct draft bindings and cannot restore the captured-string adapter. The interaction is recorded in `docs/scenarios/README.md`.
