# 0101 — Share adaptive Task Detail metadata layouts

Date: 2026-08-07

## Symptom

Pressure and Thinking needed appeared side by side for one-off tasks but as separate full-width rows for routines, even at the same macOS Task Detail width.

## Root Cause

One-off Task Detail owned an adaptive horizontal-or-vertical status-control layout, while routine Task Detail rendered duplicate pressure and thinking controls directly in a vertical stack.

## Fix

Both Task Detail paths now use one adaptive status-control layout. It keeps the controls side by side at a usable width and stacks them only when space is constrained.

## Prevention Rule

When task types present the same editable metadata, route them through one shared layout policy rather than maintaining type-specific copies.

## Regression Safeguard

`Tests/Shared/TaskDetailMacHeaderControlLayoutTests.swift` asserts that one-off and routine headers use the same adaptive control layout. The behavior is recorded in `docs/scenarios/README.md`.
