# 0701: Retire Pre-Release Flag Migration Guidance

## Status

Accepted

## Date

2026-08-30

## Revises

- [0636: Replace Configurable Flags With Built-In Behaviors](0636-replace-configurable-flags-with-built-in-behaviors.md)

## Refines

- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)

## Context

The configurable Flag model never shipped to users. Its conversion code and
migration marker were already retired, but iOS and macOS Settings still showed
an `About Flags` section describing a one-time migration. That copy suggested
that a compatibility operation still existed and that a person might have data
waiting to be converted.

## Decision

Routina treats configurable Flags as a discarded pre-release model, not as a
supported migration source. Settings explains only the current built-in Flags
and the distinction between Flags and Tags. It does not present migration copy,
a migration action, or a migration status.

Initializing or repairing the five canonical built-in catalog values remains a
current-data invariant. It is not a conversion of configurable Flags and does
not scan or rewrite task assignments.

## Consequences

- New users see only the current Flag model and do not have to interpret legacy
  product history.
- No compatibility contract is implied for configurable pre-release Flags.
- Tests guard both Settings implementations against reintroducing migration
  language.
