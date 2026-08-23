# 0564 — Group macOS task priority controls

**Status:** Superseded by [0642](../0642-unify-task-configuration-and-retire-legacy-task-kind-storage.md)
**Date:** 2026-08-13

## Context

macOS Task Detail showed Pressure, Thinking needed, Importance, and Urgency as separate cards even though they jointly describe the task's priority context. The compact Priority summary sat nearby, which made the related controls feel fragmented.

## Decision

Keep the compact derived Priority summary visible as an expandable macOS Task Detail card. Its expanded content contains four separate segmented controls for Importance, Urgency, Pressure, and Thinking needed.

The controls retain their own stored values and update actions. Importance and Urgency remain independent fields; changing one must not mark the other explicit. Derived Priority remains a calculation for ordering, and the combined Importance/Urgency matrix remains limited to filter thresholds.

## Consequences

- Priority-related task context is scanned and edited from one macOS detail section.
- `Add more details` no longer offers separate macOS actions for these four controls.
- iOS keeps its existing independent picker-pill detail presentation.
