# 0150: Add Mac Adventure Progression MVP

## Status

Accepted

## Date

2026-06-03

## Context

Routina already has achievements, Recent Wins, Focus 2048, and Stats, but the user wants the Mac app to feel more like a real game with maps, worlds, coins, stages, and items. Adding a fully persisted economy immediately would introduce data model, migration, balance, and spending semantics before the game loop has been validated.

The first version should prove whether a game-like layer makes existing Routina actions more motivating without changing the core task, focus, sleep, away, note, emotion, event, goal, or check-in systems.

## Decision

Routina Mac includes an Adventure sidebar destination as an MVP game layer. Adventure derives coins, XP, stage stars, world unlocks, and item unlocks from existing local activity history instead of persisting a separate wallet or purchase ledger.

Rewarded actions include completed routine logs, created tasks, focus blocks, completed sleep sessions, completed Away sessions, notes, emotion logs, events, goals, and place check-ins. Stages and items unlock from earned coins, rewarded action count, active days, and completed stage count.

Adventure stages are a linear path from stage 1 through stage 30. Stage stars represent the three stage requirements: coin threshold, rewarded action threshold, and active-day threshold.

Adventure is Mac-only for now. iOS, watchOS, widgets, and shared Stats behavior are not changed by this MVP.

Adventure uses generated, local asset-catalog world artwork for the first five maps. The images are bundled with the app as static resources, not fetched remotely or regenerated at runtime.

## Consequences

- Adventure can be shipped and tuned without a SwiftData migration.
- Deleting or editing underlying activity can change Adventure progress because the state is derived.
- The first art pass can be revised by replacing asset-catalog images without changing the progression rules.
- The Adventure UI should label the current stage, next locked stage, and star meanings so the map does not rely on inferred game rules.
- Future versions that need spending, purchases, limited-time rewards, or one-time claim celebrations will need explicit persisted economy state and a new decision record.
- Existing achievements remain factual Stats presentation state; Adventure is a separate motivational surface.
