# 0085: Shield Apps and Websites During Focus

## Status

Accepted

## Date

2026-05-27

## Context

Focus timers help users stay with one task, but the app did not have a way to reduce access to distracting apps or websites while a timer is running.

iOS provides privacy-preserving Screen Time APIs for this job. `FamilyControls` lets users choose apps, categories, and web domains without revealing their names to Routina, and `ManagedSettings` can shield those selected tokens while authorization is active.

## Decision

iOS Focus controls include an optional "Block apps and websites" setting. When enabled, the user can grant Screen Time access and choose the apps, categories, and websites to block using Apple's family activity picker.

Routina stores the opaque selection tokens locally and applies a `ManagedSettingsStore` shield while any `FocusSession` is active. Finishing, abandoning, or deleting active focus sessions clears the shield. If Screen Time authorization is unavailable or denied, focus timers still work, but app and website shielding does not apply.

The iOS app target declares the Family Controls entitlement so the authorization flow can run on devices and provisioned builds.

## Consequences

- Focus sessions gain optional device-level friction against selected distractions.
- The app never learns the names of selected apps or websites; it only stores Apple's opaque tokens.
- Builds and distribution now require provisioning that includes the Family Controls capability.
