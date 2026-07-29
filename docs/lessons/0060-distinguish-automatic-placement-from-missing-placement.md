# 0060 — Distinguish automatic placement from missing placement

Date: 2026-07-29

## Symptom

Task Details showed the correct live sidebar path, while Edit Task often showed
`Default` for the same task.

## Root Cause

Task Details displayed the resolved sidebar presentation, but the edit form
rendered only the optional durable custom-section ID. A nil ID means automatic
placement, not that the resolved path is unknown, so the fallback label hid
useful context already available to the host detail screen.

## Fix

The Mac edit form now receives the live Task Details breadcrumb for tasks
without an explicit custom assignment and presents it with an `Automatic`
suffix. Explicit custom paths still win, and automatic presentation does not
change the stored section ID.

## Prevention Rule

When a persisted optional override is nil but its effective value is already
resolved by the owning presentation, show the effective value with clear
automatic context instead of a generic default or missing-value label.

## Regression Safeguard

`TaskFormPresentationTests` verifies automatic breadcrumb presentation,
explicit-path precedence, the no-location fallback, and that manually assigned
tasks do not consume an automatic breadcrumb.
