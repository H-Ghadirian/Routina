# 0704 Maintain Versioned App Store Metadata

Status: Accepted

Date: 2026-08-30

Refines: [0519 Maintain Platform-Versioned Release Notes](0519-maintain-platform-versioned-release-notes.md)

## Context

Platform release notes record what changed, but they do not preserve the exact
public copy entered in App Store Connect. The main Description is intentionally
long-lived, while What's New, Promotional Text, and other metadata may change
for each version. Replacing those strings in a shared document would erase the
copy associated with an older release and make later review unreliable.

## Decision

Store App Store metadata beside the applicable platform release history, with
one Markdown file per public version named
`MAJOR.MINOR.PATCH-app-store.md`. Each file identifies its platform, public
version, build when known, status, and evidence or review date. It preserves the
exact Description and What's New copy prepared or published for that version,
plus Promotional Text or other public metadata when those fields are used.

Draft metadata stays aligned with the same version's platform release note.
After submission, preserve the submitted text as historical copy rather than
silently replacing it with a later version's wording. Corrections to shipped
metadata must be labelled and dated.

Historical metadata may be added from verified App Store evidence or directly
supplied release-owner copy even when there is not enough evidence to backfill a
complete release note. Missing fields remain explicitly unrecorded instead of
being inferred from commits or later versions.

## Consequences

- Each platform and version has a durable record of its exact App Store copy.
- Release notes remain the source for shipped scope, fixes, and known issues;
  App Store metadata files remain the source for public listing text.
- Evergreen Description changes and version-specific What's New copy can be
  reviewed independently without losing older wording.
- Historical copy does not become an unsupported claim about release contents,
  dates, or build numbers.
