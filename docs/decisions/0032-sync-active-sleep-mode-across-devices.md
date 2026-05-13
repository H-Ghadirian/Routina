# 0032: Sync Active Sleep Mode Across Devices

## Status

Accepted

## Date

2026-05-13

## Context

Sleep mode is an app-level `SleepSession`, but Routina runs on iPhone, iPad, Mac, and Apple Watch. A user starting sleep from one device expects the rest of their Routina surfaces to become quiet too.

iPhone, iPad, and Mac share SwiftData state through CloudKit. Apple Watch uses a lightweight WatchConnectivity snapshot relayed by iPhone, so it does not automatically observe every SwiftData model.

## Decision

Active sleep mode is account-wide Routina state. Starting sleep from any supported surface creates or reuses the shared active `SleepSession`; ending sleep clears active sleep across devices.

The watch snapshot includes active sleep state. The watch may start or end sleep by sending an action to iPhone, which persists the shared `SleepSession`, preserves Apple Watch as the action source, and lets CloudKit fan the change out to other SwiftData devices.

When waking, Routina ends all active sleep sessions rather than only the newest one. This handles the race where multiple devices start sleep before CloudKit has finished merging their local changes.

## Consequences

- iPhone, iPad, and Mac enter the existing sleep gate when the active `SleepSession` syncs in.
- Apple Watch presents sleep mode from its synced snapshot and hides normal routine actions while sleep is active.
- Watch-originated sleep actions are audited as Apple Watch actions instead of being attributed to the relay iPhone.
- Duplicate active sleep records can still be imported from CloudKit, but a single wake action closes them together.
