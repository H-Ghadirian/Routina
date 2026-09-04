# 0727: Move Mac Backlog Status Out of the List Header

## Status

Accepted

## Date

2026-09-04

## Refined By

- [0728: Scope Mac Backlog Reset to Each Control Tab](0728-scope-mac-backlog-reset-to-each-control-tab.md) removes the repeated inner control title and gives each tab an independent reset.
- [0737: Summarize Active Workspace Controls in Place](0737-summarize-active-workspace-controls-in-place.md) reports active Backlog controls in the existing toolbar action without restoring list-level status chrome.

## Revises

- [0632: Integrate Mac Workspaces in the Main Window](0632-integrate-mac-workspaces-in-the-main-window.md), for Backlog's internal list chrome

## Refines

- [0633: Make Mac Backlog Hierarchical and Searchable](0633-make-mac-backlog-hierarchical-and-searchable.md)
- [0721: Customize Mac Backlog Row Appearance](0721-customize-mac-backlog-row-appearance.md)
- [0722: Move Mac Task Ladder Controls to the Right Sidebar](0722-move-mac-task-ladder-controls-to-the-right-sidebar.md)

## Context

The integrated Mac workspace menu already identifies Backlog. Backlog still repeated that identity in a permanent band above its section list with a title, explanatory subtitle, task count, and refresh button. The band consumed vertical space before the content a person opened Backlog to review and made Backlog inconsistent with the newer Task Ladder workspace, whose list-level controls moved into its right-side control surface.

The task count and manual refresh remain useful workspace status and recovery controls. Removing the redundant list header should not remove either capability or change Backlog's cached presentation behavior.

## Decision

- Mac Backlog removes the permanent title, subtitle, count, refresh button, and divider above its list.
- The Backlog sidebar begins directly with its loading state, empty state, or scrollable section hierarchy.
- The task or search-result count and manual refresh button move into Backlog's existing right-side `Filter`, `Sort`, and `Appearance` control surface.
- Refresh remains disabled while an explicit load is already in progress. Reset scope is defined separately by [0728](0728-scope-mac-backlog-reset-to-each-control-tab.md).
- Backlog super-section and subsection headers, including their own counts and disclosure behavior, remain unchanged.

## Consequences

- Backlog content receives the full available list height without repeating the active workspace name.
- Count and refresh remain available in the established workspace-control location instead of occupying permanent list chrome.
- Search, filtering, sorting, appearance, hierarchy, task placement, selection, and refresh semantics are unchanged.
