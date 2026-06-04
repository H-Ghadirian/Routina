# 0153: Make Mac Adventure Worlds and Creatures Explicit Unlocks

## Status

Accepted

## Date

2026-06-04

## Refines

- [0152: Support Choice-Based Mac Adventure Unlocks](0152-support-choice-based-mac-adventure-unlocks.md)

## Context

The choice-based Adventure update made item ownership explicit, but worlds and stage creatures could still appear owned because the derived progress model marked stages as available or cleared once coin, action, and active-day thresholds were met. That made the map look like it had unlocked content on the user's behalf.

The user wants Adventure to feel like a game economy: routine progress should create eligibility and spendable coins, but the user should choose which world, creature, or item to unlock.

## Decision

Mac Adventure stores chosen world IDs and chosen stage creature IDs in local app settings using `appSettingMacAdventureUnlockedWorldIDs` and `appSettingMacAdventureUnlockedStageIDs`, alongside the existing chosen item IDs.

Derived activity history still produces total coins, XP rank, active days, rewarded actions, and stage stars. Those values determine whether a world or creature is eligible. Eligibility is not ownership. A world or creature is only unlocked when the user chooses it and it is present in the stored unlock IDs.

The Adventure wallet subtracts the costs of chosen worlds, chosen creatures, and owned items from lifetime earned coins to compute spendable coins. A user may choose any eligible world with enough spendable coins, and then choose any eligible creature within an unlocked world; the path is not required to be linear.

## Consequences

- Fresh Adventure state starts with no chosen world and no chosen creature, even if past progress makes content eligible.
- The first world can be free to choose, but it still requires an explicit user action.
- Stage stars mean requirements earned, not ownership. Popovers and guidance explain the missing requirement or unlock action.
- Local settings remain an MVP storage choice. A future cross-device or auditable economy should move these IDs into explicit persisted records.
