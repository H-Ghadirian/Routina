# 0149: Use Rolling Achievement Period Windows

## Status

Accepted

## Date

2026-06-03

## Refines

[0145](0145-separate-recent-wins-from-achievements.md)
[0146](0146-tab-achievement-status-and-periods.md)

## Context

[0145](0145-separate-recent-wins-from-achievements.md) and
[0146](0146-tab-achievement-status-and-periods.md) introduced recent wins and
achieved-badge period filters for today, this week, this month, and this year.
Using calendar period boundaries made "This Month" on June 3 only include June
1 through now, while users expect the last one-month window, such as May 3
through now.

## Decision

Achievement periods use rolling date windows through the current reference
instant. Today starts at the beginning of the current day. Week, month, and year
start at the beginning of the day one calendar week, month, or year before the
reference date, then end at the reference instant.

Both Recent Wins highlights and Achieved badge period derivation use these same
rolling windows.

## Consequences

- On June 3, This Month includes activity from May 3 through now instead of only
  June 1 through now.
- This Week and This Year follow the same rolling-window rule.
- Future-dated activity after the reference instant is not included in current
  period highlights or achieved-badge period derivation.
