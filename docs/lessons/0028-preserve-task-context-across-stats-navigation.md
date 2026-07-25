# 0028 — Preserve task context across Stats navigation

Date: 2026-07-25

## Symptom

Opening Stats from a selected Mac task detail and then returning through the Tasks toolbar segment showed `Select a task` instead of the previously open detail.

## Root Cause

Entering Stats cleared both the visible sidebar selection and the shared selected-task detail state. The Tasks return path therefore had no task context to restore.

## Fix

Stats and its Adventure presentation now clear only the visible sidebar selection. The selected task and detail state remain available, and returning to Tasks restores the matching row selection.

## Prevention Rule

When a shared-shell destination temporarily replaces task content, hide its navigation selection without discarding the underlying selected-task state unless the destination explicitly ends that task workflow.

## Regression Safeguard

The Mac Home feature test covers the Tasks → Stats → Tasks round trip and asserts that both the selected task ID and task-detail state survive. The workflow is also recorded in `docs/scenarios/README.md`.
