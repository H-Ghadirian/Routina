# 0171 — Derive optional sections from their content

Date: 2026-08-16

## Symptom

iOS Task Details showed the Linked Tasks section for tasks with no linked
tasks, adding an empty card to the default detail surface.

## Root Cause

The iOS relationship-section visibility property returned a constant `true`.
The existing `Add more details` action was already conditional on that property,
so the hard-coded value simultaneously forced the empty section to render and
made its progressive-disclosure entry point unreachable.

## Fix

The iOS view now shows Linked Tasks only when the selected task has at least one
resolved relationship. With no relationship, `Add more details` offers the
existing `Linked Task` action and opens the manual linker; adding a relationship
makes the section visible.

## Prevention Rule

Derive each optional section and its inverse Add More action from one shared
content-aware visibility condition. Never hard-code an optional section visible
when its empty state is meant to be progressively disclosed.

## Regression Safeguard

`TaskDetailPlatformActionParityTests.iosTaskDetailsHideEmptyLinkedTasksBehindAddMoreDetails`
guards both iOS detail stacks, the resolved-relationship visibility condition,
and the inverse `Linked Task` action. The iOS Task Detail Hides Empty Linked
Tasks scenario records the end-to-end expectation.
