# 0743 — Embed a Production Stats Content Fallback

## Status

Accepted

## Date

2026-09-05

## Refines

- [0742 — Externalize Stats Achievement Copy](0742-externalize-stats-achievement-copy.md)

## Context

The localized Stats achievement catalog is discovered automatically because
`SharedCore` is an Xcode file-system-synchronized group. A fresh production
build copies the catalog correctly, but an existing DerivedData product can
compile the new loader without discovering a newly added file beneath an
existing localization directory. The resulting production executable then
terminates when Stats first requests achievement content.

Searching more runtime bundles cannot recover content that was never embedded
in the product. Moving the canonical JSON out of `en.lproj` would weaken its
localization ownership, while duplicating the authored content in Swift would
undo the separation established by Decision 0742.

## Decision

The macOS and iOS production targets explicitly copy the canonical localized
Stats achievement JSON to a uniquely named, unlocalized fallback resource.
The typed loader prefers the normal localized catalog and accepts the fallback
only when synchronized resource discovery did not place the primary resource
in any runtime bundle.

The fallback is generated from the same source JSON during every production
build; it is not a second authored copy. Missing or invalid source content
continues to fail the build or the catalog invariant.

## Consequences

- Production builds no longer depend solely on Xcode discovering a newly added
  localized file in a synchronized folder.
- Normal localization lookup remains the preferred path.
- Achievement wording still has one source of truth outside Swift.
- The production bundle carries one additional copy of the roughly 10 KB
  English catalog as a recovery path.
