# 0152: Support Choice-Based Mac Adventure Unlocks

## Status

Accepted

## Date

2026-06-04

## Refines

- [0150: Add Mac Adventure Progression MVP](0150-add-mac-adventure-progression-mvp.md)

## Context

The first Adventure MVP proved the basic map, coin, XP, stage, world, and item presentation, but it still felt too automatic. Items appeared unlocked as soon as the user crossed thresholds, and stage cards were connected by a visible route line. That made the screen read like a linear checklist on top of map art instead of a game layer where the user can make choices.

The user wants Adventure to give more freedom: earned coins should create a budget, and the user should choose which available companion, artifact, booster, or tool to unlock.

## Decision

Mac Adventure keeps deriving coins, XP, stage stars, and stage/world availability from existing activity history. Item ownership now has a small local persistence layer: `appSettingMacAdventureOwnedItemIDs` stores the item IDs the user has chosen to unlock.

The Adventure wallet treats total derived coins as lifetime earnings, subtracts the cost of owned known items, and exposes the remainder as spendable coins. Any eligible item can be unlocked when its progress requirements are met and enough spendable coins remain. Ownership is intentionally local app setting state for this MVP, not a SwiftData economy ledger.

Adventure maps present stages as scattered encounters over world artwork. They do not draw route lines over the generated map images. Stage markers use generated creature-face sheets, one sheet per world with six stage creatures cropped into individual markers, so each stage has a character that visually belongs to its background. Stage stars continue to mean the three requirements: coins, rewarded actions, and active days.

## Consequences

- The user can choose among available item unlocks instead of receiving every item automatically.
- Deleting or editing underlying activity can reduce spendable coins, but already owned item IDs remain owned for the MVP.
- This avoids a SwiftData migration while preserving the core choice loop for Mac.
- Future versions that need cross-device inventory, refunds, limited-time rewards, rarity, item effects, or purchase history should replace the local setting with explicit persisted economy state.
