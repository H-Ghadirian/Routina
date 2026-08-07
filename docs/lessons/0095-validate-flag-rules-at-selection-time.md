# 0095 — Validate Flag rules at selection time

Date: 2026-08-07

## Symptom

An auto-assume behavior could be enabled through a task-local toggle, with no
reusable Flag workflow or clear feedback when a future rule was incompatible
with the task's schedule.

## Root Cause

Eligibility was coupled to the scheduling UI instead of being applied when a
behavior Flag was assigned. Hiding ineligible Flags would have made defined
Flags appear to disappear from the task form.

## Fix

Auto-assume completion is now a typed Flag rule. Add and Edit Task leave all
Flags visible, reject only an incompatible auto-assume selection, and show the
specific reason and supported schedules. Save paths materialize active Flag
rules into the existing completion field, while assigned Flags persist across
temporary schedule incompatibility.

## Prevention Rule

For behavior Flags whose eligibility depends on task data, show the Flag in
every form and validate at the attempted assignment boundary. Do not use form
visibility or disabled appearance as the explanation.

## Regression Safeguard

The Swift test suite covers the existing auto-assume schedule eligibility and
task-form catalog selection paths; iOS and macOS app builds compile both Flag
form surfaces.
