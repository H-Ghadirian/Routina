# User Experience

This directory is Routina's source of truth for the product from the person's perspective. It describes who the experience is for, what people need, which situations Routina should support, and what a successful outcome feels like.

It is intentionally different from a feature inventory, technical specification, or user manual. A use case starts with a person's situation and desired outcome, not with a screen or data model.

## Start Here

- [Users and Needs](users-and-needs.md) describes the working understanding of the people Routina serves and the outcomes they need.
- [UX Principles](ux-principles.md) defines the qualities that should remain true across the experience.
- [Use Cases](use-cases.md) is the central catalog of situations, journeys, successful outcomes, and concrete examples.
- [Use-Case Template](use-case-template.md) keeps future additions consistent.

## Experience Loop

Routina supports one connected loop:

**Capture -> Decide -> Plan -> Act -> Record -> Review -> Adapt**

A feature should make at least one part of this loop meaningfully easier without making the rest less trustworthy.

## Relationship to Other Documentation

| Documentation | What it answers |
| --- | --- |
| User Experience | What is the person trying to achieve, and what should the experience provide? |
| [Current Behavior](../current-behavior/README.md) | What does Routina currently do? |
| [Decisions](../decisions/README.md) | Why did Routina choose that product or implementation direction? |
| [Scenarios](../scenarios/README.md) | Which exact behavior is protected against regression? |

When the documents disagree, do not silently rewrite one to match another. Treat the mismatch as a product question. Current-behavior pages remain authoritative for shipped behavior; user-experience pages remain authoritative for the intended user outcome. Resolve a durable change through the decision process.

## Maintenance Rule

Update these documents in the same change whenever:

- the user describes a new or revised use case;
- an app change affects a person's journey, choices, expectations, outcome, recovery path, privacy, limitation, or feature availability;
- user feedback changes the team's understanding of a need;
- a feature moves between proposed, experimental, and production availability.

Pure refactors and internal performance changes do not need a use-case edit unless they materially change the perceived experience. Bug fixes should update a use case when the correction reveals or changes the intended journey; they still require the separate lesson and regression documentation defined elsewhere.

## Writing Rules

- Begin with the person's context, need, and desired outcome.
- Use plain product language. Keep source types, reducers, persistence, and other implementation details in technical documents.
- Include at least one realistic example for every use case.
- State meaningful failure, recovery, trust, or accessibility expectations.
- Name platform differences only when they affect the journey.
- Mark availability honestly as production, development experiment, proposed, or unknown.
- Distinguish verified user evidence from working assumptions. Do not turn an internal guess into a claimed user fact.
- Link to current behavior and decisions for detail instead of duplicating their long contracts.
