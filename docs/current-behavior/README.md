# Current Behavior

This directory summarizes Routina's current product and engineering behavior in a form that is faster to read than the full decision history.

Decision records in `docs/decisions/` remain the source for why choices were made. These current-behavior pages are the source for what contributors should preserve now.

The [User Experience](../user-experience/README.md) documents separately describe who needs the behavior, the situation in which they need it, and the outcome Routina should provide.

## How to Use

- For a product or UX change, read the relevant user need and use case before reading the implementation-facing contract here.
- Read the relevant current-behavior page before changing a feature area.
- Read the relevant current-behavior page before answering a substantive question about what Routina currently does.
- Follow links back to decision records when the reason, tradeoffs, or migration context matters.
- If a requested change contradicts current behavior or an existing decision, pause before implementation, explain the conflict briefly, and get explicit user permission before proceeding.
- Update the relevant current-behavior page when a change intentionally revises durable app behavior.
- Update the relevant current-behavior page when an investigation establishes durable behavior that was missing or inaccurately described, even if the app itself did not change.
- Update the relevant user-experience documents in the same change when a person's journey, expected outcome, example, limitation, or feature availability changes.
- Add or update a regression scenario in `docs/scenarios/` when a fixed bug should not reappear.
- Do not duplicate every implementation detail here. Capture the behavior that future work must not accidentally break, including consequential prerequisites, absence behavior, recovery paths, platform scope, and distinctions between similarly named features.

## Areas

- [Tasks](tasks.md)
- [Planner](planner.md)
- [Stats](stats.md)
- [Settings](settings.md)
- [Places](places.md)
- [UI](ui.md)
- [Release](release.md)
