# 0374: Move Unlimited Task Override to Beta Experiments

Status: Accepted

Date: 2026-07-12

Refines: [0293 Add Settings Unlimited Task Override While Products Are Unavailable](0293-add-settings-unlimited-task-override-while-products-unavailable.md)

## Context

The temporary unlimited-task override exists only while StoreKit products are unavailable, and it is meant for manual testing rather than a normal purchase workflow. Keeping it in a standalone Purchases section made the Support & About page look like it had production purchase controls even though the control is a temporary escape hatch.

Routina already collects optional, stabilizing, or testing-only app surfaces under Support & About -> Beta Experiments. The override matches that mental model better than the user-facing Purchases grouping.

## Decision

Settings -> Support & About -> Beta Experiments exposes the `Unlock unlimited tasks` toggle on iOS and macOS. Turning it on continues to resolve the same testing unlimited-task entitlement from [0293](0293-add-settings-unlimited-task-override-while-products-unavailable.md).

The standalone Purchases section is removed while the temporary override is the only visible purchase-related control in Support & About.

## Consequences

- Manual development and production testing can still bypass the active-task limit while StoreKit products are unavailable.
- Support & About keeps temporary testing controls grouped with other beta experiments instead of presenting a separate Purchases card.
- Before release monetization is enforced, remove or hide this temporary Beta Experiments toggle and remove the development default from [0293](0293-add-settings-unlimited-task-override-while-products-unavailable.md).
