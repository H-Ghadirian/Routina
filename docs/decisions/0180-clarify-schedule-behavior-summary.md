# 0180: Clarify Schedule Behavior Badge Preview

- **Status:** Accepted
- **Date:** 2026-06-07
- **Refines:** [0046](0046-label-routine-schedule-behavior-as-due-and-gentle.md)

## Context

Decision [0046](0046-label-routine-schedule-behavior-as-due-and-gentle.md) introduced Due and Gentle routine behavior labels and asked forms to preview row/detail badges. The badge examples are useful because they show what users will later see in task rows, but the preview became confusing when it also included multiple explanatory schedule sentences.

## Decision

Routine forms should keep a compact row badge preview for schedule behavior and explain it with one concise sentence.

- The preview should show only the expected row badges, such as Today/Overdue for Due and Ready/Gentle nudge for Gentle.
- The preview should not show a separate routine type title or icon, because that can be mistaken for another row badge.
- The preview should have one short explanatory line about what those badges mean.
- The preview should not also repeat cadence, availability, or longer behavioral explanations.
- Real task rows and task details remain the source of truth for actual current status badges.
- Due/Gentle labels and persisted fixed/soft schedule behavior names remain unchanged.

## Consequences

The scheduling form teaches the row badges without turning the preview into a dense explanation block. Shared model code keeps preview badge data because Mac and iOS forms both use it.
