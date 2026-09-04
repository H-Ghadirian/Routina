# 0719 — Externalize Localizable and Structured Product Copy

## Status

Accepted

## Date

2026-09-04

## Refines

- [0136 — Refactor Large Files Judiciously](0136-refactor-large-files-judiciously.md)
- [0610 — Expose Product Help Through Local AI Connections](0610-expose-product-help-through-local-ai-connections.md)
- [0717 — Ratchet Code Quality With Shared Boundaries](0717-ratchet-code-quality-with-shared-boundaries.md)

## Context

Routina historically kept nearly all English product copy in Swift source. Short
labels close to their controls can remain readable, compiler-extractable
localization keys, but large help, Settings, and Adventure declarations mixed
content authoring with models and behavior. That made translation inventory hard
to review, inflated already-large Swift files, and made content-only changes look
like implementation changes.

Moving every literal blindly would also reduce clarity. Stable identifiers,
symbols, persistence values, diagnostics, and small implementation-local strings
are not interchangeable with translatable product copy. Structured content needs
typed validation, while ordinary SwiftUI copy should continue using Apple's
compiler-supported localization flow.

## Decision

Routina uses two complementary resource boundaries:

- Each shipping target owns a String Catalog. The main iOS and macOS apps share
  `AppResources/Localizable.xcstrings`; the Widget and Watch extension keep their
  own catalogs. Compiler-extractable SwiftUI keys may remain beside the control
  they describe, with the catalogs providing the translation inventory.
- Long or repeated structured product content lives in localized resource files
  and is decoded into typed models. The initial resource-backed catalogs cover
  product Help, Settings section search metadata and Quick Add guidance, and Mac
  Adventure progression content.
- Resource loaders validate completeness and stable identifiers before exposing
  content. A missing or malformed bundled catalog is a build/development
  invariant failure rather than a partially usable runtime state.
- Resource records keep behavior-bearing identifiers, thresholds, symbols, and
  relationships explicit. Extracting copy must not change those values or the
  user-visible English output.
- `script/sync_string_catalogs.sh` merges compiler localization output from the
  persistent macOS, iOS, Widget, and Watch build directories into the committed
  target catalogs. The quality guard checks that these catalogs and structured
  resource boundaries remain present and do not silently collapse.
- New runtime-generated user-facing strings that cannot be compiler-extracted
  should use explicit localized resources rather than introducing untracked
  English. Logs, test fixtures, protocol values, and internal identifiers are not
  localized merely to reduce source line counts.

English is the initial source language. This decision creates a maintainable
localization boundary; it does not claim that additional translations already
exist.

## Consequences

- Translators and reviewers can inspect the app's target-specific copy without
  searching the whole Swift tree.
- Large content declarations no longer dominate behavior files, while short
  control labels can stay readable at their call sites.
- Help, Settings metadata, Quick Add guidance, and Adventure content can change
  without editing their behavioral implementations.
- Adding a target or resource-backed catalog requires including it in build
  resources, validation, catalog synchronization, and the quality guard.
- File size should improve as a consequence of clearer ownership, but resource
  extraction is not a license to move identifiers or small cohesive logic into
  opaque data files.
