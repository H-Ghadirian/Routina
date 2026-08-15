# 0573: Centralize User-Perspective Product Documentation

## Status

Accepted

## Date

2026-08-15

## Refines

- [0250: Split Current Behavior and Regression Scenarios From Decision History](0250-split-current-behavior-and-regression-scenarios.md)
- [0251: Require Decision Conflict Check Before Implementation](0251-require-decision-conflict-check-before-implementation.md)

## Context

Routina's decision records and current-behavior pages contain substantial
product intent, but they are organized around durable choices and feature
contracts. The person using the app, their situation, their underlying need,
and a realistic successful example are often embedded inside long technical
documents or left implicit.

That makes it harder to evaluate whether a new idea solves a real problem and
easier for later app changes to preserve mechanics while drifting away from the
intended experience. It also risks presenting internal product assumptions as
validated user facts.

## Decision

Routina will maintain `docs/user-experience/` as the central source of truth for
the product from the person's perspective. It contains the working user model,
user needs, UX principles, and an outcome-oriented use-case catalog with
realistic examples and honest availability.

These documents add an experience-intent layer without replacing the existing
documentation layers:

- user-experience documents describe who needs what, in which situation, and
  what a successful journey should provide;
- current-behavior pages state what the app does now;
- decision records explain durable choices and tradeoffs;
- regression scenarios state concrete behavior that tests should protect;
- lessons capture reusable knowledge from defects.

Whenever the user describes a new or revised use case, that use case is added
or updated as part of the same work. Whenever an app change materially changes
a journey, expected outcome, example, limitation, recovery path, privacy
expectation, or feature availability, the related user-experience documentation
is updated in the same change.

User-experience documents use plain language and avoid implementation detail.
They mark unvalidated needs as working assumptions until user research,
feedback, or repeated real-world evidence supports them. If a request conflicts
with documented experience intent, contributors pause and make the conflict
explicit before implementation under the same rule used for current behavior
and prior decisions.

## Consequences

- Product discussions have one discoverable starting point grounded in user
  situations and outcomes.
- Feature work must preserve or deliberately revise the use case it serves,
  not only its implementation contract.
- Existing decision and current-behavior documentation remains authoritative
  for rationale and shipped behavior without carrying the full UX narrative.
- Examples make ambiguous product requests easier to discuss and test.
- Working assumptions remain visible, creating a concrete backlog for future
  user research instead of being mistaken for validated evidence.
