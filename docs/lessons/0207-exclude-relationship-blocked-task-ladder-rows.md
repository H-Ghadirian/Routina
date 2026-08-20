# 0207 — Exclude relationship-blocked Task Ladder rows

Date: 2026-08-20

## Symptom

Mac Task Ladder showed a task whose details correctly reported `Blocked by
linked task`. The task remained in the ladder because its stored Todo state was
still Ready or In Progress.

## Root Cause

Task Ladder filtered only the persisted `TodoState.blocked` value. Relationship
blocking was derived separately by Home and Task Details, so the cached ladder
presentation treated a relationship-blocked task as actionable.

## Fix

Task Ladder now resolves active relationship blockers while building its cached
presentation and excludes both stored and relationship-derived blocked tasks.
The macOS loader also supplies recorded completion dates so repeating
prerequisite handoffs use the shared history-aware resolution rules.

## Prevention Rule

Every surface that ranks or counts actionable tasks must use the same effective
availability state as Home and Task Details. Persisted workflow state alone is
not sufficient when linked-task relationships can temporarily block a task.

## Regression Safeguard

`TaskRankingPresentationTests.relationshipBlockedTasksStayOutOfTheLadderEvenWhenStoredStateIsActionable`
verifies that a relationship-blocked task is absent from sections, eligible IDs,
and counts. The Task Ladder scenario records the expected cached-presentation
contract and repeating completion-handoff behavior.
