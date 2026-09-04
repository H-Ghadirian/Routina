# 0728: Scope Mac Backlog Reset to Each Control Tab

## Status

Accepted

## Date

2026-09-04

## Revises

- [0721: Customize Mac Backlog Row Appearance](0721-customize-mac-backlog-row-appearance.md), for reset behavior in Backlog's tabbed controls

## Refines

- [0727: Move Mac Backlog Status Out of the List Header](0727-move-mac-backlog-status-out-of-the-list-header.md)

## Context

Backlog's right-side control surface already names the workspace at its outer boundary and labels its three tabs. A second large `Backlog` title and explanatory subtitle above those tabs repeated context without helping a person change anything.

The same inner header also offered one Reset action for Filter and Sort while Appearance was durable and unaffected. That made the action's scope unclear and forced a person to discard two independent configurations together even when only one needed correction.

## Decision

- Backlog's inner control content removes the repeated `Backlog` title and explanatory subtitle. The `Filter`, `Sort`, and `Appearance` tabs lead the content.
- A compact utility row retains the current task or search-result count and manual refresh action.
- The selected tab owns an explicitly named reset action: `Reset Filter`, `Reset Sort`, or `Reset Appearance`.
- Reset Filter restores every transient filter field and matching mode while preserving the selected sort order and durable row appearance.
- Reset Sort restores `Default` ordering while preserving filters and durable row appearance.
- Reset Appearance restores Backlog's sparse multiline default row configuration while preserving filters and sorting.
- Each reset is disabled only when its own tab is already at its default.

## Consequences

- The control surface begins with the choices that establish context instead of repeating the workspace name.
- A person can recover one kind of configuration without losing deliberate choices in the other tabs.
- Backlog's count, refresh, cached presentation, and preference-persistence behavior remain unchanged.
