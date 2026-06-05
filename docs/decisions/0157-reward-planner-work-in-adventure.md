# 0157: Reward Planner Work in Adventure

## Status

Accepted

## Date

2026-06-05

## Refines

- [0150: Add Mac Adventure Progression MVP](0150-add-mac-adventure-progression-mvp.md)
- [0005: Show Timeline Activity in the Day Planner](0005-show-timeline-activity-in-day-planner.md)
- [0008: Confirm Timeline Activity as Planner Blocks](0008-confirm-timeline-activity-as-planner-block.md)

## Context

Adventure rewards many completed actions, but the Planner is also a core Routina workspace. Users can spend real effort shaping a day before the work is done: creating blocks, allocating time, and refining the plan. If Adventure ignores that effort, planning feels disconnected from the game economy.

Planner rewards should not overpower completed work because planning is intent, not proof of completion. They should be small, visible, and derived from persisted planner records so the same history survives app restarts and sync.

## Decision

Mac Adventure derives planner rewards from persisted `DayPlanBlockRecord` data:

- Saved planner blocks earn a small coin reward.
- Full planned hours earn an additional small reward.
- A planner block that is updated after creation earns one refinement reward.

These planner rewards count toward Adventure coins, XP, active days, and stage action progress. The Earn Coins guide lists each planner source separately so users can understand how planner work contributes.

## Consequences

- Planner interaction becomes part of Adventure without adding a separate economy table.
- Users can make progress by planning, but completion-heavy activity remains the strongest reward path.
- Future planner interaction rewards should prefer durable persisted evidence over transient UI state.
