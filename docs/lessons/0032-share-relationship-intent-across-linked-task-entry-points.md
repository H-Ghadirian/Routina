# 0032 — Share relationship intent across linked-task entry points

Date: 2026-07-26

## Symptom

Mac Task Details used a compact relationship-first action row, while Edit Task showed two large buttons without a relationship choice. Creating a linked task from Edit Task therefore relied on relationship state outside the visible control.

## Root Cause

The create and edit form relationship editor gained the two destinations without adopting Task Details' interaction order. Its creation callback also carried no relationship value, so the form could not explicitly seed creation from the user's current choice.

## Fix

Edit Task now uses the compact relationship picker followed by `Create New Task` and `Link a Task`. The selected relationship is passed into new-task creation and initializes the existing-task picker.

## Prevention Rule

Equivalent relationship entry points should share the same interaction order and pass the visible relationship choice directly into whichever destination the user selects.

## Regression Safeguard

The Mac task-detail reducer coverage protects relationship-kind selection, the Home presentation coverage protects inverse relationship seeding, and the linked-task regression scenario requires the compact relationship-first row on both Mac surfaces.
