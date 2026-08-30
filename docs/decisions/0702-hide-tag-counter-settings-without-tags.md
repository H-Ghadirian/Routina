# 0702: Hide Tag Counter Settings Without Tags

## Status

Accepted

## Date

2026-08-30

## Refines

- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)

## Context

Tag Counter display changes how saved Tags are rendered. On an empty catalog,
the setting has no visible subject and cannot produce a meaningful result, yet
both Settings implementations presented it before the useful `No tags yet`
guidance.

## Decision

iOS and macOS Settings show Tag Counters only while at least one saved Tag
exists. The Saved Tags or All Tags section remains visible when the catalog is
empty so it can explain how Tags appear. Creating, importing, restoring, or
synchronizing the first Tag reveals the counter setting automatically; removing
the final Tag hides it without changing the stored display preference.

## Consequences

- Empty Tag settings focus on the actionable explanation instead of an inert
  presentation preference.
- The existing counter choice survives temporary empty catalogs and applies
  again when a Tag becomes available.
- Both platforms derive the visibility from the same loaded saved-tag state.
