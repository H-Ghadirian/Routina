# Current Behavior

This directory summarizes Routina's current product and engineering behavior in a form that is faster to read than the full decision history.

Decision records in `docs/decisions/` remain the source for why choices were made. These current-behavior pages are the source for what contributors should preserve now.

## How to Use

- Read the relevant current-behavior page before changing a feature area.
- Follow links back to decision records when the reason, tradeoffs, or migration context matters.
- If a requested change contradicts current behavior or an existing decision, pause before implementation, explain the conflict briefly, and get explicit user permission before proceeding.
- Update the relevant current-behavior page when a change intentionally revises durable app behavior.
- Add or update a regression scenario in `docs/scenarios/` when a fixed bug should not reappear.
- Do not duplicate every implementation detail here. Capture the behavior that future work must not accidentally break.

## Areas

- [Tasks](tasks.md)
- [Planner](planner.md)
- [Stats](stats.md)
- [Settings](settings.md)
- [Places](places.md)
