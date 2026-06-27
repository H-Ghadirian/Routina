# 0293: Add Settings Unlimited Task Override While Products Are Unavailable

Status: Accepted

Date: 2026-06-27

Refines: [0290 Limit Free Active Tasks Behind Subscription](0290-limit-free-active-tasks-behind-subscription.md)

## Context

The active-task subscription gate from [0290](0290-limit-free-active-tasks-behind-subscription.md) is working, but the StoreKit products are not available yet during manual app testing. Once a user has 10 active tasks, the paywall blocks creating more tasks and the user cannot complete a purchase to unlock the entitlement.

Automated tests already bypass this gate, and the subscription store already supports an explicit unlimited-task testing entitlement. Manual development and production smoke testing need a temporary escape hatch until the product catalog is available.

## Decision

Settings > Support & About > Purchases exposes an `Unlock unlimited tasks` toggle. Turning it on resolves the existing testing unlimited-task entitlement so task creation can continue beyond the free active-task limit in both development and production builds.

iOS and macOS development app configurations keep `RoutinaUnlockAllTasks` enabled as the default value for this setting. Production app configurations default the setting off, so the freemium active-task gate from [0290](0290-limit-free-active-tasks-behind-subscription.md) remains active unless the user explicitly enables the temporary override.

## Consequences

- Manual development and production testing can continue creating tasks while StoreKit products are unavailable.
- The paywall, product catalog, purchase, restore, and pending-save flow remain implemented and available to test by turning the override off.
- Before release monetization is enforced, remove or hide the temporary Settings override and remove the development default.
