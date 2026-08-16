# 0176 — Append search fallbacks to partial results

Date: 2026-08-16

## Symptom

On Mac, searching `watch` omitted a known matching task, while refining the
query to `watch m` made that task appear under `Search Results`.

## Root Cause

The task-list presentation consulted its fallback catalog only when the normal
sidebar presentation was empty. The broader query produced other ordinary
sections, so it skipped every matching task suppressed from normal placement.
The narrower query removed those ordinary results and accidentally unlocked the
fallback.

## Fix

Non-empty Mac task search now appends unmatched fallback rows beside ordinary
and Flag-reveal sections. Presented task IDs are removed from the fallback so a
task still appears only once.

## Prevention Rule

Do not use total empty-state detection to decide whether partial search results
are complete. Merge each eligible search source, deduplicate by stable semantic
identity, and let emptiness control only the empty-state UI.

## Regression Safeguard

The `Mac Toolbar Search Shows Every Eligible Suppressed Task Match` scenario and
`HomeTaskListFilteringTests.sidebarSearchFallbackAddsSuppressedMatchesBesideOrdinaryMatches`
cover a broad query that has both an ordinary result and a placement-suppressed
match.
