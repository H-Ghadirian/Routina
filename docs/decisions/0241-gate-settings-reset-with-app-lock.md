# 0241: Gate Settings Reset With App Lock

## Status

Accepted

## Date

2026-06-25

## Refines

- [0166: Use App Lock for Cloud Data Reset](0166-use-app-lock-for-cloud-data-reset.md)
- [0235: Require Authentication to Disable App Lock](0235-require-authentication-to-disable-app-lock.md)

## Context

Routina settings can affect privacy, notifications, app locking, beta surfaces, blocking, appearance, and synced display preferences. A one-tap reset is useful when settings have drifted, but it should not be easier to apply than other sensitive reset flows.

## Decision

Settings -> General includes a destructive reset action that restores settings preferences to their defaults. The action is available only after App Lock has been enabled, and applying it requires a fresh device owner authentication pass.

The reset is scoped to settings and preference storage. It does not delete user routines, timeline history, saved places, notes, goals, attachments, or other SwiftData user content.

## Consequences

- Users must turn on App Lock before they can reset settings.
- A failed or canceled authentication leaves existing settings unchanged.
- Successful reset can restore App Lock itself to its default off state because the protected operation has already been authenticated.
