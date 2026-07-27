# 0047 — Localize dynamic controls to their owner

Date: 2026-07-27

## Symptom

Selecting `Multi-day` made a new `Planning` action appear far below the changed
control in the Mac form's `Add More Details` palette. The palette mutation made
a duration edit look like an unrelated feature had been enabled.

## Root Cause

The form used one semantic `supportsPlanning` flag both to decide whether
planning was valid and whether Planning belonged in the global optional-section
catalog. When duration or cadence changed planning eligibility, the global
palette changed even though the dependency was owned by routine scheduling.

## Fix

Mac forms now resolve Planning placement separately from eligibility. Todos
retain a standalone Planning section, while eligible routine Planning renders
inside `Schedule details` and never enters the routine optional-section
catalog.

## Prevention Rule

Do not let a conditional feature's eligibility implicitly choose its visual
owner. Resolve placement independently, and keep dynamically eligible controls
inside the stable disclosure or section that contains their causal settings.

## Regression Safeguard

`Tests/macOS/FormSectionTests.swift` verifies that unsupported and supported
routine Planning never resolve to a standalone section, while todo Planning
retains its standalone placement. The wide Mac task-form scenario also requires
the `Add More Details` palette to remain stable when Multi-day enables routine
Planning.
