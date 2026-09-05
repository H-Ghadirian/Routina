# 0741 — Ratchet Stable Quality Identities and Semantic Catalogs

## Status

Accepted

## Date

2026-09-05

## Refines

- [0717 — Ratchet Code Quality With Shared Boundaries](0717-ratchet-code-quality-with-shared-boundaries.md)
- [0719 — Externalize Localizable and Structured Product Copy](0719-externalize-localizable-and-structured-product-copy.md)

## Context

SwiftLint's native baseline records source positions. Moving otherwise unchanged
code shifted later findings and made the quality gate report historical debt as
new violations. That behavior discouraged healthy extraction and did not measure
whether the set of offending source constructs had actually grown.

The localization guard counted lines printed by `xcstringstool`. A String
Catalog key may itself contain a newline, so printed lines are not catalog keys.
Catalog synchronization also had no read-only mode, forcing contributors to
modify committed resources merely to discover drift.

## Decision

Routina keeps SwiftLint's generated baseline as the debt inventory, but the
quality guard compares findings by stable file, rule, and offending source-text
identity, preserving the multiplicity of duplicate findings. Source line and
column changes alone do not consume a new budget. Moving a violation into a new
file or introducing new offending text still fails the gate.

Every successful cleanup regenerates the baseline and lowers applicable
aggregate budgets to the repository's verified state.

String Catalog counts come from the JSON `strings` object rather than rendered
tool output. `script/sync_string_catalogs.sh --check` synchronizes temporary
copies and compares canonicalized JSON, so object ordering does not look like
content drift and the committed catalogs remain unchanged during validation.
Synchronization reads only the current host architecture's compiler output
(overridable with `ROUTINA_LOCALIZATION_ARCH`) because persistent Derived Data
may retain obsolete output for architectures built in earlier sessions.
User-visible values constructed as runtime `String` properties use
`String(localized:)` explicitly so compiler synchronization retains their keys;
mere catalog presence is not evidence that a runtime value remains localized.

## Consequences

- Ownership-preserving file extraction no longer causes false SwiftLint debt.
- New per-file/rule/source findings still fail automatically.
- The baseline and size/logging budgets ratchet down with completed cleanup.
- Multiline localization keys count once, and each catalog floor reflects the
  real committed inventory.
- Runtime-generated user-facing values remain visible to compiler extraction.
- Contributors can validate compiler-extracted localization state without
  mutating their worktree, provided all target build outputs for the selected
  architecture are current.
