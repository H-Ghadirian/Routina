# 0599: Separate Mac Stats Priority Filters

## Status

Accepted

## Date

2026-08-16

## Refines

- [0563: Present Importance and Urgency as Independent Task Controls](0563-present-importance-and-urgency-as-independent-task-controls.md)
- [0581: Separate iOS Priority Filter Controls](0581-separate-ios-priority-filter-controls.md)

## Context

iOS Stats already presents Importance and Urgency as independent minimum
thresholds, but the Mac Stats sidebar still exposed one combined matrix. The
matrix made changing one threshold require selecting the other at the same
time, even though the two values represent independent judgments.

The existing combined filter cell remains useful for matching and persistence:
a task must satisfy both active minimum thresholds. Only its Mac Stats
presentation needs to change.

## Decision

The Mac Stats sidebar presents separate collapsible `Importance` and `Urgency`
filter sections. Each section offers `All` plus its meaningful minimum
thresholds and changes only its own axis. `All` clears that axis while
preserving any active threshold on the other axis.

The sections continue to write the existing combined Importance/Urgency filter
cell. Matching, persistence, restoration, clearing, and active-filter counts
remain unchanged. Other Mac filter surfaces retain their current presentation.

## Consequences

- People can adjust a Stats Importance or Urgency minimum without reselecting
  the other threshold.
- Existing saved Stats filter values remain compatible.
- Mac Stats aligns with the independent iOS control model without changing
  filter results or broadening the change to other Mac filter surfaces.
