# 0223 — Keep empty organization containers reachable

Date: 2026-08-22

## Symptom

A newly created Backlog super section disappeared while it contained no tasks,
so the section's subsection-creation control was unreachable until a task was
assigned through another surface.

## Root Cause

The Backlog presentation treated its durable section catalog only as a wrapper
for non-empty task groups. It compacted away every empty section even though the
same presentation also owned section-management actions.

## Fix

Backlog now preserves every Backlog super section and subsection in the normal
cached presentation, including empty entries. Search results may still omit
nonmatching empty branches because management controls remain available again
after clearing the query.

## Prevention Rule

If an organizational container owns the only action for creating or managing
its descendants, do not derive that container's visibility solely from current
item count. Keep the durable catalog reachable independently from filtered
content.

## Regression Safeguard

`BacklogTaskListPresentationTests.keepsEmptyBacklogSuperSectionsAndSubsectionsReachable`
protects empty hierarchy visibility, and the matching regression scenario is
recorded in `docs/scenarios/README.md`.
