# 0268 — Scope lazy-row identity to presentation changes

Date: 2026-08-29

## Symptom

After selecting a row in Mac Task Ladder's Pressure view and switching to
Urgency, selecting a different row could leave the previous row tinted, omit the
new row's tint, or tint both rows while Task Details showed only the new task.

## Root Cause

The row's inner selection chrome had an identity derived from selection, but the
outer lazy item still used only the task UUID. The same task UUID was therefore
reused while the task moved through a different metric's section hierarchy.
That retained outer item could keep the earlier row subtree and prevent a later
selection identity change from replacing both visible row states.

## Fix

Each outer Task Ladder lazy row now has an identity containing its namespaced
task-or-group node, metric, Base/Now mode, section, and selected state. A metric
or value-mode switch recreates the affected presentation's rows; a selection
move within an unchanged presentation recreates only the old and new lazy rows.
The raw task UUID remains as a nested scroll target, so search location still
works without assigning a new identity to the whole scrolling container.

## Prevention Rule

When one semantic item can move between substantially different lazy-list
presentations, do not use its domain ID alone as the retained outer row identity.
Scope row identity to the presentation boundary that changes its hierarchy, and
put any stable scroll target inside that boundary. Keep ordinary invalidation at
row scope rather than resetting the list or scroll view.

## Regression Safeguard

`TaskRankingPresentationTests.taskLadderLazyRowIdentityRefreshesMetricLayoutsAndOnlyChangedSelectionRows`
proves that changing metrics invalidates every row identity, while changing the
selection in one metric invalidates only the previous and newly selected rows.
The Mac Task Ladder scenario also covers Pressure-to-Urgency selection continuity
and requires exactly one tint matching Task Details.
