# Routina Documentation

Start here when deciding what Routina should do or changing how it behaves.

## Documentation Map

| Question | Source of truth |
| --- | --- |
| Who is the experience for, what do they need, and what should a successful journey feel like? | [User Experience](user-experience/README.md) |
| What does the app do now? | [Current Behavior](current-behavior/README.md) |
| Why was a durable product or engineering choice made? | [Decision Log](decisions/README.md) |
| Which concrete behaviors must not regress? | [Regression Scenarios](scenarios/README.md) |
| What reusable knowledge came from a defect? | [Lessons Learned](lessons/README.md) |
| Which known product or engineering gaps remain? | [Product Debt](debt/README.md) |
| What shipped on each platform and version? | [Release Notes](releases/README.md) |

These sources complement one another. They should link to related documents instead of copying implementation detail between them.

## Before Changing the Product

1. Read the relevant user need and use case.
2. Read the relevant current-behavior page.
3. Follow its decision links when rationale or tradeoffs matter.
4. If the requested change conflicts with the documented experience or current behavior, pause and make the conflict explicit before implementation.
5. Update every affected documentation layer in the same change.

## After Changing the Product

- Update [User Experience](user-experience/README.md) when the user's situation, need, journey, outcome, example, limitation, or feature availability changes.
- Update [Current Behavior](current-behavior/README.md) when durable app behavior changes.
- Add or supersede a [Decision](decisions/README.md) when the change makes a long-term choice.
- Add a [Regression Scenario](scenarios/README.md) and automated safeguard for behavior that must not return.
- Add a [Lesson](lessons/README.md) after every bug fix.
