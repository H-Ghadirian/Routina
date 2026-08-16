# 0188 — Deduplicate planner placements by meaning

Date: 2026-08-16

## Symptom

One timed task appeared several times in the same Calendar day. The overlap
layout squeezed the copies into narrow side-by-side columns, making each copy
look like a separate block.

## Root Cause

Planner storage deduplicated only by block ID. Synchronization could preserve
several records with different IDs but the same task, day, start, and duration,
so every record reached the timed overlap layout as a distinct placement.

## Fix

Day-plan sanitization now also collapses identical semantic placements to the
most recently updated block. Loading immediately presents one block, and the
next save removes the stale records while preserving other time slots for that
task and coincident blocks for other tasks.

## Prevention Rule

When synchronization can assign different record IDs to one logical item,
storage-boundary deduplication must include the smallest safe semantic identity,
not only the persistence ID. That semantic key must preserve explicitly allowed
repetitions.

## Regression Safeguard

`DayPlanStorageTests.loadingDuplicateSemanticPlacementsUsesTheMostRecentlyUpdatedBlockAndRepairsOnSave`
creates different-ID copies of one placement, verifies only the newest is
loaded, verifies valid neighboring placements remain, and verifies saving
repairs persistence. The Planner regression scenario records the same contract.

Related lesson: [0087 — Deduplicate planner block records before rendering](0087-deduplicate-planner-block-records-before-rendering.md).
