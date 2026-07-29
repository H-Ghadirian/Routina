# 0066 — Refetch iOS Timeline after sync invalidation

Date: 2026-07-29

## Symptom

Activity completed today was visible in the Mac Timeline after syncing, while
the iOS Timeline still stopped at yesterday.

## Root Cause

The Mac Timeline refetched an explicit SwiftData snapshot when Routina's
coalesced semantic update notification arrived. The iOS Timeline instead held
unbounded `@Query` collections and only rebuilt its reducer snapshot when those
arrays emitted a local change. A remote store import could therefore complete
without crossing the iOS Timeline's visible invalidation boundary.

## Fix

iOS and macOS now share the same explicit Timeline data-snapshot fetcher. The
iOS Timeline refetches on appearance, on Routina's semantic update notification,
and when the app becomes active, then rebuilds its derived newest-first sections
from that stable snapshot.

## Prevention Rule

Do not assume a long-lived SwiftData `@Query` is a sufficient invalidation
boundary for a CloudKit-backed scrolling surface. Subscribe to the app-owned
semantic sync notification and explicitly refetch the cached presentation
snapshot after remote imports and app activation.

## Regression Safeguard

`TimelineLogicTests` verifies that an explicit refetch sees activity inserted
from another model context and that iOS Timeline contains the semantic
notification and activation refresh paths without unbounded `@Query` or
whole-history change tokens.
