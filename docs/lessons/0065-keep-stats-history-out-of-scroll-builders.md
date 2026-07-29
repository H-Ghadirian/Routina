# 0065 — Keep Stats history out of scroll builders

Date: 2026-07-29

## Symptom

Scrolling the iOS Stats dashboard was visibly laggy and slow, especially with a
large task and activity history.

## Root Cause

The dashboard used an eager stack for every report and erased several section
types with `AnyView`. Its Achievements and Recent Wins builders also walked the
complete focus, sleep, away, completion, emotion, note, goal, and place history
whenever SwiftUI rebuilt those sections. In addition, Stats observed both raw
SwiftData saves and Routina's semantic update notification, so one logical
change could trigger repeated whole-snapshot reloads.

## Fix

The iOS dashboard now builds report sections with a `LazyVStack` and preserves
their concrete SwiftUI types. Achievement and win presentation is calculated
once when the reducer receives a refreshed data snapshot, then filtered by
feature availability from that compact snapshot. iOS Stats listens to the
semantic update notification and coalesces refresh bursts for one second.

## Prevention Rule

Never fetch or derive whole-history Stats content from a view, section, or row
builder reached during scrolling. Build one immutable presentation snapshot at
an explicit data invalidation boundary, render it lazily with stable types, and
coalesce duplicate persistence notifications before loading another snapshot.

## Regression Safeguard

`StatsFeatureDerivedStateSupportTests` verifies the iOS Stats scroll builder
remains lazy, contains no achievement-history derivations or raw SwiftData save
listener, and keeps reducer-side snapshot/debounce boundaries. The iOS UI
performance suite also scrolls a Stats database seeded with 12,000 activity
records.
