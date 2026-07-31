# 0466: Harden App Store Release Surfaces

Status: Accepted

Date: 2026-07-31

Refines: [0290 Limit Free Active Tasks Behind Subscription](0290-limit-free-active-tasks-behind-subscription.md), [0293 Add Settings Unlimited Task Override While Products Are Unavailable](0293-add-settings-unlimited-task-override-while-products-unavailable.md), [0374 Move Unlimited Task Override to Beta Experiments](0374-move-unlimited-task-override-to-beta-experiments.md), [0417 Route Feature Data Loading Through Reducers](0417-route-feature-data-loading-through-reducers.md)

## Context

Routina's StoreKit paywall displayed product names, billing periods, and prices, but it did not keep Privacy Policy and Terms of Use links or automatic-renewal disclosure visible in the purchase flow. The temporary unlimited-task testing override also remained reachable in production diagnostics and a previously stored override could bypass StoreKit after release.

Calendar task import always advertised Outlook even when the production bundle had no Microsoft Graph client ID. That exposed a path which could only end in a configuration error instead of a working user feature.

## Decision

The subscription paywall shows automatic-renewal and cancellation disclosure together with visible Privacy Policy and Terms of Use links. Support & About exposes the same legal links on iOS and macOS. These links use the published Routina support page and its stable `privacy` and `terms` anchors.

The temporary unlimited-task override is a development-app capability. Development builds keep the Beta Experiments toggle and configured default for manual testing. Production builds hide the toggle and ignore environment, configured, and persisted override values; only verified StoreKit entitlements unlock unlimited tasks in production.

Calendar task import offers Outlook only when `RoutinaMicrosoftGraphClientID` resolves to a nonempty value. When Microsoft Graph is not configured, Apple Calendar is the sole source and user-facing Settings copy does not advertise Outlook. The existing Outlook implementation remains available automatically when a valid client ID is supplied.

## Consequences

- Purchase terms and legal policies remain reachable at the point where a user chooses or restores a plan.
- A stored testing preference cannot silently grant a production entitlement.
- Development builds retain the manual StoreKit escape hatch used for local testing.
- Reviewers and users do not encounter a nonfunctional Outlook sign-in choice in unconfigured builds.
- Publishing or moving the support website must preserve the legal anchors or update the centralized public URLs in the app.
