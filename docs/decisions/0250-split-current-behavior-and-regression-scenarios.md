# 0250: Split Current Behavior and Regression Scenarios From Decision History

## Status

Accepted

## Date

2026-06-19

## Context

The decision log has grown into a useful but heavy history of architecture, product behavior, build setup, and convention choices. Reading every relevant numbered record is becoming slower as the project accumulates refinements and superseded decisions.

Some fixed issues can also reappear after unrelated changes. Decision records explain why the product should behave a certain way, but they do not by themselves create executable protection against regressions.

## Decision

Routina will keep decision records in `docs/decisions/` as historical rationale.

Routina will also maintain current-behavior summaries in `docs/current-behavior/`. These pages describe the active product contract for major feature areas and link back to the decision records that explain the reasoning.

Routina will maintain regression scenarios in `docs/scenarios/`. A recurring bug fix is not complete until the expected behavior is written as a scenario and covered by at least one automated test, unless the change explicitly documents why automation is not practical.

New decision records should be reserved for durable architecture, convention, data model, dependency, product behavior, build setup, or other long-term choices. Small fixes and narrow implementation corrections should normally update tests and, when appropriate, scenarios instead of adding more decision records.

## Consequences

- Contributors get a shorter path to the current truth before changing a feature area.
- Decision records remain valuable for rationale, tradeoffs, and migration context without serving as the only day-to-day product contract.
- Repeated bugs gain explicit scenario coverage and are less likely to return silently.
- Documentation work is split by purpose: decisions explain why, current-behavior pages state what, and scenarios define concrete expected behavior to protect with tests.

