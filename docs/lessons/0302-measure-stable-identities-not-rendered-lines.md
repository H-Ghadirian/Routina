# 0302 — Measure stable identities, not rendered lines

Date: 2026-09-05

## Symptom

The code-quality guard failed after behavior-preserving file edits because old
SwiftLint findings moved to new line numbers. Its localization totals also
overcounted catalogs containing multiline keys, and catalog checks could confuse
JSON object reordering or obsolete architecture output with source drift.

## Root Cause

The lint gate delegated comparison to a position-sensitive baseline instead of
the durable identity of each finding. Localization inventory used the number of
lines printed by a presentation command rather than the catalog data model, and
catalog synchronization lacked a semantic read-only comparison.
Persistent Derived Data can also retain `.stringsdata` for an architecture that
is not part of the latest build, so scanning every architecture revived removed
keys and missed newly extracted replacements.
Several still-visible labels were returned through plain `String` properties;
their catalog entries existed, but the compiler could not associate those
runtime values with the localization inventory.

## Fix

The guard now compares SwiftLint findings by file, rule, and offending source
text while retaining duplicate counts. It reads String Catalog totals directly
from each JSON `strings` object. Catalog synchronization gained a `--check` mode
that works on temporary copies and compares canonicalized JSON. The repaired
metrics then locked in lower lint, file-size, and direct-logging budgets. Catalog
synchronization now reads only the current host architecture by default and
provides an explicit architecture override for other build environments.
The affected runtime-generated labels now use `String(localized:)` explicitly.

## Prevention Rule

Quality metrics must measure durable repository facts, not presentation output
or incidental source positions. A read-only validation path must compare
semantic content and leave the contributor's worktree untouched.
Compiler-derived validation must also scope persistent build artifacts to the
architecture being verified instead of merging stale outputs from older builds.

## Regression Safeguard

`script/code_quality_guard.sh` fails on any stable SwiftLint identity above its
committed multiplicity and validates true catalog key floors.
`script/sync_string_catalogs.sh --check` fails when current compiler extraction
changes canonical catalog content.

Related decision: [0741 — Ratchet stable quality identities and semantic catalogs](../decisions/0741-ratchet-stable-quality-identities-and-semantic-catalogs.md).
