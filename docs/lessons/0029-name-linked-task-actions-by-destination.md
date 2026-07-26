# 0029 — Name linked-task actions by their destination

Date: 2026-07-25

## Symptom

On Mac, `Add Linked Task` opened new-task creation from Task Details but opened the existing-task picker from Edit Task. Identical wording led to different destinations and made linking behavior unpredictable.

## Root Cause

The detail and edit surfaces independently exposed only one of two valid relationship workflows. Both workflows inherited a generic add label even though one creates a task and the other selects an existing task.

## Fix

Mac Task Details and Edit Task now expose both `Create New Task` and `Link a Task`. Creation retains the inverse-relationship seed, while linking retains the existing-task picker.

## Prevention Rule

When a relationship UI supports both creating a target and selecting an existing target, expose separate actions whose labels name those destinations. Do not reuse a generic add label for different navigation outcomes.

## Regression Safeguard

Shared presentation coverage protects the two distinct labels, the existing Home feature test protects inverse-relationship seeding for creation, and the regression scenario records the paired behavior expected on both Mac surfaces.
