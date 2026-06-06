# 0169: Hide Mac Website Blocking for Release Stabilization

## Status

Accepted

## Date

2026-06-06

## Refines

- [0160: Support Mac Browser Website Blocking](0160-support-mac-browser-website-blocking.md)
- [0159: Support Entered Website Blocking on iOS](0159-support-entered-website-blocking-on-ios.md)
- [0158: Generalize Protected Mode Blocking Settings](0158-generalize-protected-mode-blocking-settings.md)

## Context

Mac browser-level website blocking is implemented as best-effort browser automation, but release testing showed unreliable enforcement in Safari and Chromium browsers. Users should not see a website blocking setting in the release build until the behavior is dependable enough to ship.

Mac app blocking remains release-ready and should continue to appear in Blocking settings.

## Decision

Production Mac builds hide the Websites card in Blocking settings and do not start Mac website blocking enforcement, even if saved website domains already exist in local defaults.

Sandbox, development, and automated test modes keep the website blocking UI and enforcement code available so the feature can continue to be debugged without reintroducing it to release users.

## Consequences

- Release users see protected mode toggles and Mac app blocking only.
- Saved website domain preferences remain intact for future re-enablement, but production builds ignore them while this release gate is active.
- Releasing Mac website blocking later should be an explicit product decision that removes this gate after Safari and Chromium enforcement are verified.
