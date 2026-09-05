# 0305 — Resolve content from the owning bundle

Date: 2026-09-05

## Symptom

Routina terminated while deriving Stats achievements with a fatal error that
`StatsAchievementContentCatalog.json` was missing, even though the localized
JSON resource belonged to the project.

## Root Cause

The non-SwiftPM loader searched only `Bundle.main`. That is the application
bundle during an ordinary launch, but Xcode previews, hosted tests, and other
runtime hosts can make a different bundle main. The lookup therefore treated a
host-context mismatch as a missing resource.

## Fix

The loader now checks the application bundle, the bundle that owns the catalog
code, and the process's loaded bundles and frameworks, removing duplicate
bundle URLs. It also explicitly falls back to the English localization before
retaining the existing fail-fast behavior for a genuinely missing or invalid
catalog.

## Prevention Rule

Code-backed localized resources must resolve from the bundle that owns the
code, with the application bundle treated as one candidate rather than the
only possible runtime bundle.

## Regression Safeguard

A focused catalog test requires the runtime bundle candidates to resolve
`StatsAchievementContentCatalog.json`. SwiftPM tests and hosted macOS tests run
that assertion in their distinct bundle environments, while final app builds
are inspected and launched on macOS and iOS.
