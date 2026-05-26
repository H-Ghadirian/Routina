# 0067: Separate Prod and Dev Deep Link Schemes

## Status

Accepted

## Date

2026-05-26

## Supersedes

- The single-scheme registration portion of [0061: Share Stable Routina Deep Links](0061-share-stable-routina-deep-links.md)

## Context

Routina has production and development apps that can be installed side by side on macOS and iOS. Registering the same custom URL scheme in both builds lets Launch Services choose whichever app most recently claimed `routina://`. A production task link can therefore open the development app, where the referenced record is absent.

## Decision

Production builds keep registering and emitting `routina://` entity links. Development builds register and emit `routina-dev://` entity links. Runtime URL generation reads the app's configured deep-link scheme, with bundle identifier fallback for extensions.

Deep-link parsing accepts both `routina` and `routina-dev` so already-stored notifications, active-focus state, and in-process dispatch can still decode known Routina entity links. The development app does not register the production `routina` scheme.

## Consequences

- Links copied from the production app are routed to the production app even when a development build is installed.
- Links copied from the development app stay isolated to the development app.
- Microsoft Graph redirect URI guidance follows the active build's scheme, so development OAuth configuration should register `routina-dev://auth/microsoft`.
- Future URL-producing surfaces should use `RoutinaDeepLink.url` or `AppEnvironment.deepLinkURLScheme` instead of hardcoding `routina://`.
