# 0709 — Defer iPad Support Until It Is Ready

**Status:** Accepted
**Date:** 2026-08-31

## Revises

- [0519 — Maintain Platform-Versioned Release Notes](0519-maintain-platform-versioned-release-notes.md)
- [0568 — Defer the Watch Companion from the First Production Release](0568-defer-watch-companion-from-first-production-release.md)

## Context

Routina's iOS app and widget were configured as universal iPhone and iPad
targets, and the first production phase was documented as shipping both device
families. The adaptive iPad implementation is not release-ready and has multiple
unresolved issues. Leaving iPad in the targeted device families would present
that implementation as supported and would add a platform whose quality cannot
yet be trusted to the first release's validation and support obligations.

The adaptive source can still be useful for future work. Removing it now would
mix a release-scope correction with a large code deletion and would make a later
iPad release more expensive without improving the current iPhone product.

## Decision

The current iOS release supports iPhone only. Every iOS app, test-bundle, and
widget build configuration declares targeted device family `1`, and the iOS app
Info.plists contain no iPad-specific orientation declarations.

Retain adaptive iPad source where it does not compromise the iPhone build, but
treat it as dormant development work rather than a supported, tested, or
release-ready surface. The first production phase therefore consists of the
iPhone app with its production widget and the macOS app; both iPad and the Apple
Watch companion are deferred.

Mark the prepared iPadOS 1.4.0 note as deferred before release. The iPadOS
release-history folder preserves planning history, but a future iPad candidate
requires an explicit release-scope decision, a restored iPad device family, an
updated current-behavior and user-experience contract, and complete iPad
functional, layout, performance, archive, and launch verification.

## Consequences

- The iOS app, its widget extensions, and their test bundles build for iPhone,
  not as universal iPhone/iPad products.
- App Store submission copy and checklists must describe an iPhone app rather
  than a universal app.
- Existing iPad-specific source is not evidence of availability or support.
- iPad issues do not block the first iPhone release, but they must be resolved
  and verified before iPad can return to release scope.
- Cross-device product promises for the current release cover iPhone and Mac.
