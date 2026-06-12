# 0215: Re-enable Mac Website Blocking Behind Beta Toggle

## Status

Accepted

## Date

2026-06-12

## Context

Mac website blocking is currently hidden from most release users due prior stabilization concerns in Safari/Chromium enforcement. We still want to keep the feature available for users who opt in via a Settings-based beta switch, similar to other guarded features.

## Decision

Mac website blocking is no longer permanently disabled in release; instead, it is disabled by default and exposed only when `appSettingMacWebsiteBlockingEnabled` is turned on from Settings (Mac → General → Beta Experiments).

The website blocking availability check now uses this user setting in addition to sandbox mode, so:

- Debug/sandbox builds retain access by default.
- Release users need an explicit setting switch to enable websites in Blocking settings.

## Consequences

- Adds a new default key: `appSettingMacWebsiteBlockingEnabled` (default `false`).
- Adds a Settings toggle in Mac General → Beta Experiments.
- Keeps website settings hidden and inactive until explicitly enabled.
- Does not alter existing website domain data or app-blocking behavior when the website toggle is disabled.
