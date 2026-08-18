# 0602: Preserve Durable Project Investigation Findings

## Status

Accepted

## Date

2026-08-17

## Refines

- [0250: Split Current Behavior and Regression Scenarios From Decision History](0250-split-current-behavior-and-regression-scenarios.md)
- [0251: Require Decision Conflict Check Before Implementation](0251-require-decision-conflict-check-before-implementation.md)
- [0573: Centralize User-Perspective Product Documentation](0573-centralize-user-perspective-product-documentation.md)

## Context

Answering a substantive question about Routina can require tracing several code
paths, comparing similarly named features, and checking which prerequisites
make an action appear. When the verified result remains only in a conversation,
later contributors must repeat the investigation and can still give an answer
that omits an important condition.

The dedicated Mac Backlog exposed this problem. Existing documentation said
that tasks could move into Backlog paths, but did not state that no generic
Backlog destination exists and that a Backlog section must be created before
Home or task-form menus show any Backlog path. A chronological discovery log
would preserve the conversation but create another source that becomes stale
instead of correcting the canonical description.

## Decision

Before answering a substantive question about current Routina behavior,
contributors read the relevant current-behavior page and follow its links when
rationale or experience intent matters.

When a meaningful investigation establishes a durable, verified fact that is
missing from or inaccurately described by project documentation, the finding is
recorded in the canonical topic-based document as part of the same work, even
when no application code changes. Documentation should include consequential
prerequisites, behavior when prerequisites are absent, platform or feature
availability, recovery paths, and distinctions between similarly named
features. Verified behavior, inference, and open questions remain explicitly
separate.

The existing documentation layers retain their distinct purposes:

- current-behavior pages state what Routina does now and receive corrected or
  newly verified product facts;
- decision records explain durable choices and tradeoffs, but a new record is
  not required for every discovered fact;
- user-experience documents record needs, journeys, feedback-backed
  limitations, and intended outcomes;
- scenarios define regression contracts that tests should protect;
- lessons preserve reusable knowledge after a defect is fixed.

Contributors correct the existing canonical document rather than creating a
chronological discovery diary. Transient debugging observations,
machine-specific state, and unverified hypotheses are not documented as
current behavior.

## Consequences

- Expensive project investigations leave a searchable result for later work.
- Future answers begin from the latest canonical description instead of
  reconstructing behavior from code alone.
- Preconditions and absence behavior are less likely to be lost behind an
  implementation's successful path.
- Topic-based documents remain correctable when the product changes, avoiding
  a second time-ordered knowledge archive that silently goes stale.
- Documentation changes remain proportional: durable findings are preserved,
  while temporary investigative noise is discarded.
