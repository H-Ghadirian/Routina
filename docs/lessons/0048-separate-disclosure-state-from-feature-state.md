# 0048 — Separate disclosure state from feature state

Date: 2026-07-27

## Symptom

Expanding `More schedule options` revealed a detached checkbox labeled
`Use fixed schedule details`, followed by a second expansion of fields. Weekly
schedules also showed the same intended time in both `Start` and `At`.

## Root Cause

The UI relied on default platform styling for a semantic mode that enabled an
entire group of controls, and a bounded inner frame was centered before it was
anchored to the disclosure. Presentation also exposed both the recurrence
threshold timestamp and occurrence time even though users should edit one
schedule time.

## Fix

The disclosure now owns visibility only. A leading-aligned inset panel uses a
switch for optional `Fixed schedule`, a `Required` status for mandatory fixed
details, and a desktop collapsed summary. Single-time desktop schedules show
Start date and occurrence time once, while the hidden threshold time follows
the first occurrence time.

## Prevention Rule

Do not use one visual affordance to imply both visibility and persisted feature
state. Give the disclosure and enabled mode separate roles, choose control
weight based on how much subordinate functionality it governs, and avoid
exposing two editable fields for one user intention.

## Regression Safeguard

`TaskFormPresentationTests` protects fixed-start visibility, desktop inline
layout, and collapsed summary policy. `RoutineRecurrenceDraftTests` protects
alignment between the hidden fixed-start threshold and the first visible
occurrence time. The wide Mac task-form scenario records the grouped switch,
required state, and leading alignment.
