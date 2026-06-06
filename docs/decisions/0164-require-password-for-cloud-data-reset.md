# 0164 Require a Password for Cloud Data Reset

- Status: Accepted
- Date: 2026-06-06

## Context

Routina's iCloud reset action is intentionally destructive: it deletes local SwiftData records from the current device and lets the CloudKit-backed store propagate those deletes. A simple destructive alert is too easy to confirm accidentally for an action that can remove production data across devices.

## Decision

Before deleting iCloud data, Routina requires the user to create a one-time deletion password and re-enter it in the confirmation flow. The password is never persisted and is cleared when the confirmation is cancelled, dismissed, or accepted. The reducer also validates the match before beginning the reset, so the safeguard is not only a UI-disabled button.

## Consequences

- Accidental taps cannot trigger the reset without deliberate typed confirmation.
- The reset flow remains available without adding account-level credential storage.
- Future destructive data-wide actions should use similarly explicit confirmation gates.
