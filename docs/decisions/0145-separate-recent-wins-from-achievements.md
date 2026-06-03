# 0145: Separate Recent Wins From Achievements

## Status

Accepted

## Date

2026-06-03

## Supersedes

[0141](superseded/0141-show-achievement-period-celebrations.md)

## Context

[0141](superseded/0141-show-achievement-period-celebrations.md) placed Recent Wins inside the Achievements section before all-time badge progress. That kept celebrations near badges, but it made the Achievements surface mix two different jobs: recent period summaries and long-term badge progress. Once Stats gained more top-level scopes, Recent Wins could stand on its own without crowding the badge category picker.

## Decision

Stats includes a top-level Wins scope on iOS and macOS. The Wins scope shows the Recent Wins period cards for Today, This Week, This Month, and This Year, including only periods with recorded accomplishments.

The Achievements scope returns to all-time badge progress only. Its category picker continues to filter badge domains, and Recent Wins no longer appears inside the Achievements section.

## Consequences

- Users can choose between recent period accomplishments and long-term badge progress from the main Stats category picker.
- The Recent Wins empty state is visible when no current periods have accomplishments, because the standalone tab can no longer disappear silently.
- Period summaries remain derived from existing history and require no new persistence.
