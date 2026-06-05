# 0159: Support Entered Website Blocking on iOS

## Status

Accepted

## Date

2026-06-05

## Context

The Blocking settings page allowed users to choose apps, categories, and websites through Apple's Screen Time picker on iOS. Users also need a direct way to type a website domain such as `youtube.com` instead of relying only on the picker.

The native macOS app still cannot enforce website blocking with the existing app-blocking mechanism. `ManagedSettings` web-content domain filtering is available to the iOS Screen Time path, while the corresponding web-content APIs are unavailable to macOS apps in the current SDK.

## Decision

Routina stores manually entered website domains as normalized domain records with Focus, Away, and Sleep applicability. On iPhone and iPad, when Screen Time blocking is enabled and authorized, Routina applies entered domains with `ManagedSettings` web-content filtering in addition to the opaque app/category/website tokens selected in the Screen Time picker.

macOS Settings explains that typed website blocking is not enforced natively on Mac yet. Native Mac website enforcement remains deferred until Routina adopts a supported content-filter or browser-extension path.

## Consequences

- Users can type website domains directly on iOS and have them blocked during enabled protected modes.
- Existing picker-selected website tokens and manually entered domains can be active at the same time.
- Domain storage remains local app settings state and keeps per-domain mode applicability.
- Routina still does not present native macOS website blocking as implemented.
