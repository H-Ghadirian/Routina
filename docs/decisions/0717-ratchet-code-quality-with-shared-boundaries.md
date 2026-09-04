# 0717 — Ratchet Code Quality With Shared Boundaries

## Status

Accepted

## Date

2026-09-03

## Refines

- [0136 — Refactor Large Files Judiciously](0136-refactor-large-files-judiciously.md)
- [0417 — Route Feature Data Loading Through Reducers](0417-route-feature-data-loading-through-reducers.md)
- [0418 — Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)

## Context

Routina has strong behavioral coverage, but its source tree contains substantial
historical style and size debt. Enforcing a new formatter or low absolute size
limit against the complete tree would create a broad mechanical rewrite and
would contradict Decision 0136's requirement to extract meaningful ownership
boundaries rather than split files only to satisfy a number.

Several iOS and macOS implementations were byte-identical, shared package code
was rooted at the repository root through a long exclusion list, and operational
failures used unstructured standard output. Swift 6 concurrency compatibility
also depends on a small number of explicit unsafe annotations whose count should
not grow without review.

## Decision

Code quality improves through a checked ratchet:

- SwiftLint evaluates the complete production and test tree against a committed
  baseline. New violations fail the quality gate while existing findings remain
  visible for incremental removal.
- Swift format is mandatory for newly added Swift files. Expanding enforcement
  to all touched files is allowed once doing so no longer creates unrelated
  whole-file churn.
- Aggregate budgets prevent growth in oversized production files, concurrency
  escape annotations, source-inspection tests, raw app `print` calls, and
  byte-identical iOS/macOS files. A budget may decrease with cleanup; increasing
  one requires an explicit review of this decision and the guard.
- Identical app implementations live once in `SharedCore`. Platform adapters
  remain separate only when behavior or target isolation differs.
- `RoutinaAppSupport` is rooted at `SharedCore`, not the repository root. Its
  explicit source list remains temporarily while app-owned types are migrated in
  behavior-preserving slices.
- Operational logging flows through an injected client backed by unified
  logging. App code does not write directly to standard output; command-line
  tools may continue using standard output as their user interface.
- SwiftUI environment defaults do not use `nonisolated(unsafe)` to hold mutable
  reference values or non-sendable callbacks. Mutable coordinators use optional
  environment values with view-owned fallbacks, while callbacks declare their
  actor and `Sendable` contract.
- Source-text assertions remain reserved for architectural invariants that are
  impractical to express through executable behavior. All such tests use one
  path-safe loading helper; the quality guard separately tracks the number of
  consuming test files and rejects direct source-file reads outside that helper.

GitHub Actions runs the quality guard, shared package tests, macOS tests, and iOS
Simulator tests with Xcode 26.4. Local completion verification remains governed
by the project build instructions and Decision 0713.

## Consequences

- New code cannot silently increase the measured debt categories.
- Existing formatting and large-file debt can be reduced without an all-at-once
  rewrite or meaningless file fragmentation.
- Shared implementations cannot drift independently between app targets.
- CI failures identify whether a regression is stylistic, structural, shared,
  or platform-specific.
- Baseline and budget reductions are expected to accompany future cleanup; they
  are not permanent allowances for the current debt.
