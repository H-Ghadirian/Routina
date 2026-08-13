# 0565 — Collapse macOS Task Ladder value sections

**Status:** Accepted

**Date:** 2026-08-13

## Context

Task Ladder groups active work into metric-value sections such as High, Medium, and Low Pressure. When several values contain many tasks, scanning one group should not require keeping every other group expanded.

## Decision

Each Task Ladder value section has an independently clickable header that collapses or expands its rows. Sections begin expanded when the Task Ladder window opens. The local disclosure state is not task data and is not persisted.

## Consequences

- A person can focus on one metric value without changing any task, ordering, rank key, or visible task eligibility.
- The cached ranking snapshot continues to contain every active task; collapsing only suppresses row rendering for that section.
- Moving between Task Ladder sections and reversing a metric retain their existing behavior.
