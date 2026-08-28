# 0261 — Prune filtered hierarchy at the presentation boundary

Date: 2026-08-28

## Symptom

Applying Backlog filters removed nonmatching task rows but left their super
sections and subsections visible with a count of zero, making the filtered
result noisy and harder to scan.

## Root Cause

Backlog presentation construction pruned empty hierarchy only for text search.
The filter path reused filtered task buckets but retained the normal browsing
contract that deliberately keeps empty catalog destinations reachable.

## Fix

Cached presentation construction now prunes empty subsections and then prunes
super sections without a direct match or retained subsection whenever search
or any Backlog filter is active. Clearing filters restores the complete catalog
hierarchy, including intentionally empty destinations.

## Prevention Rule

Hierarchical filters must derive both visible rows and visible branches at the
same cached presentation boundary. Preserve intentionally empty destinations
only in normal browsing, not in a narrowed result whose hierarchy should
explain its matches.

## Regression Safeguard

`Tests/Shared/BacklogTaskListPresentationTests.swift` verifies filtered pruning
and unfiltered restoration for both hierarchy levels.
`Tests/macOS/BacklogFeatureTests.swift` verifies the reducer rebuild applies and
reverses the same behavior when filters change and clear. The Mac Backlog
scenario records the corresponding user-visible contract.
