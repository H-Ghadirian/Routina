# 0235: Require Authentication to Disable App Lock

## Status

Accepted

## Date

2026-06-13

## Refines

- [0166: Use App Lock for Cloud Data Reset](0166-use-app-lock-for-cloud-data-reset.md)

## Context

App Lock protects the user's routines and gates sensitive actions with device owner authentication. Enabling App Lock already requires fresh authentication, but disabling it without the same check creates an easy way to bypass that protection once the app is open or when the lock screen cannot authenticate.

## Decision

Turning App Lock off requires a fresh device owner authentication pass, using the same Local Authentication-backed model as unlocking Routina and confirming protected reset actions. If authentication succeeds, Routina persists App Lock as off. If authentication fails or device authentication is unavailable, App Lock stays on and no setting change is persisted.

The locked App Lock overlay does not provide an unauthenticated "Turn Off App Lock" fallback.

## Consequences

- Users cannot disable App Lock without Touch ID, Face ID, device passcode, or Mac password authentication.
- A canceled or failed disable attempt leaves the protection active.
- Devices where authentication is temporarily unavailable require fixing authentication before App Lock can be disabled.
