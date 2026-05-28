# 0097: Preserve Compact More Destination Across Tab Switches

- Status: Accepted
- Date: 2026-05-28

## Context

Compact iOS uses an app-owned More tab for Goals, Stats, and Settings. The More stack intentionally avoids a general `NavigationPath` because the nested feature screens already own their own navigation behavior, and a full path model risks reintroducing restoration and gesture bugs.

The More tab was clearing its top-level destination whenever the user switched to another bottom tab. That made More behave unlike Home, where an opened task detail remains selected while moving between tabs.

## Decision

The compact More tab preserves its top-level destination across ordinary bottom-tab switches. If the user opens More > Settings, switches to Home or Timeline, and returns to More, Routina restores Settings instead of popping back to the More root list.

Routina keeps the existing lightweight optional destination enum instead of adopting a full `NavigationPath`. Explicit reset actions can still clear the More destination, such as tapping the already-selected More tab or invoking the Task add tab.

## Consequences

- More behaves more like the other tabs for top-level feature destinations.
- Settings sub-page history is still owned by Settings' local navigation and is not guaranteed by this decision.
- Future deeper More-stack restoration should be designed separately instead of expanding this optional destination into an unbounded path casually.
