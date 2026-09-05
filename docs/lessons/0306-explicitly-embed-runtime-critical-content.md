# 0306 — Explicitly embed runtime-critical content

Date: 2026-09-05

## Symptom

The production app still terminated when opening Stats after bundle lookup was
made more flexible because no candidate bundle contained the newly externalized
achievement catalog.

## Root Cause

Xcode's file-system-synchronized resource discovery copied the new localized
JSON in fresh build caches, but an existing production DerivedData product
could compile the loader without adding the newly discovered resource. Runtime
bundle search cannot recover a file omitted from the built product.

## Fix

Both production targets now explicitly copy the canonical catalog to a uniquely
named fallback resource. The loader prefers normal localized content and uses
that build-generated fallback only when the primary resource is absent.

## Prevention Rule

When application startup or a major workspace requires newly externalized
structured content, give production targets an explicit build output instead
of relying only on synchronized-folder discovery.

## Regression Safeguard

Configuration tests require both production projects to declare the fallback
build phase, its canonical input, and its bundle output. Production build
verification also checks that both the localized catalog and generated fallback
exist before launching the apps.

Related: [0305 — Resolve content from the owning bundle](0305-resolve-content-from-the-owning-bundle.md)
