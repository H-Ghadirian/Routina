# 0514: Defer iOS Location Services Until Places Release

## Status

Accepted

## Date

2026-08-09

## Refines

[0275: Hide Places Behind Beta Toggle](0275-hide-places-behind-beta-toggle.md) and [0470: Keep Beta Experiments Out of Production](0470-keep-beta-experiments-out-of-production.md)

## Context

Places is intentionally retained as an iOS development experiment. Production already hides its UI, resolves its preference to disabled, and omits the location purpose string. However, the production source still compiled the `CLLocationManager` implementation that asks for when-in-use authorization and reads a device coordinate. Keeping that implementation in the release binary does not match the unavailable production surface and can expose an unnecessary protected-API validation risk.

## Decision

The iOS development target defines `ROUTINA_IOS_LOCATION_SERVICES` and retains the full one-shot `CLLocationManager` implementation for Places testing. The iOS production target does not define that condition. It compiles no `CLLocationManager` implementation and supplies a no-op location snapshot through `LocationClient` instead.

The Places source, models, saved-place data, and development UI remain in the repository. Promoting Places to a production feature requires an explicit release decision to restore the compilation condition and the production location purpose string.

## Consequences

- The production iOS binary cannot request or read device location while Places remains unavailable.
- Development builds continue to support current-location maps, place availability, and automatic place check-ins.
- Existing Places data remains compatible with sync, backup, and a future deliberate release.
- Any production release of Places requires a newly reviewed privacy disclosure and configuration verification.
