# 0051 — Isolate Add Task event catalog refresh

Date: 2026-07-27

## Symptom

Changing schedule, timing, and due-style controls in Add Task became increasingly laggy and could make the form appear to freeze when the event history was large.

## Root Cause

The Add Task root views converted and sorted the complete SwiftData event query into event-link candidates inside an `onChange` input expression. Every unrelated feature-state mutation reevaluated that expression, so schedule controls repeatedly walked the full event history even when the Events section and event data had not changed.

## Fix

Event-link candidate derivation now lives in a small query-owning synchronization view. The view is equatable by Add Task store identity, so parent form mutations do not reevaluate its body; SwiftData query invalidation still refreshes candidates when the event catalog itself changes.

## Prevention Rule

Do not put full-query mapping, sorting, or model-property access in a parent form body or `onChange` input. Isolate catalog observers from unrelated feature state and derive their immutable presentation values only when the query changes.

## Regression Safeguard

`AddRoutineFeatureTests.addTaskInteractionWorkStaysOutOfTheSwiftUIRenderPath` verifies that platform Add Task roots no longer own the event query or candidate derivation and that they install the equatable query-isolation view.
