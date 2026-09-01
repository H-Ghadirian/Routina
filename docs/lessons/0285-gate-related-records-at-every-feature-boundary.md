# 0285 — Gate related records at every feature boundary

Date: 2026-09-01

## Symptom

Mac task rows and full Task Details displayed linked Goals while the Goals toggle
was off. Settings and the development screenshot fixture could also expose Goal
names, counts, or records even though users cannot create Goals in this release.

## Root Cause

The feature flag guarded the Goal workspace and several creation controls, but
task-row display models, detail summaries, Settings data queries and mutations,
AI snapshot metadata, and fixture construction consumed persisted Goal data
directly. Preserving disabled data had been mistaken for permission to present it.

## Fix

Goal availability is now applied before building task-row and search models,
presenting task details, handling deep links, deriving or mutating Settings Tags,
describing task-data access, and generating release fixtures. Existing user Goals
and task links remain stored; only older fixture-owned Goal rows are retired.

## Prevention Rule

For an optional related-record feature, audit every read, presentation, mutation,
deep-link, search-index, export-adjacent copy, and fixture path. Preserve disabled
user data for compatibility, but pass an empty catalog or reject the route before
deriving any user-facing result.

## Regression Safeguard

Shared display-factory and AI snapshot tests verify that disabled Goal metadata is
absent. App reducer tests protect disabled Goal deep links on iOS and Mac. Settings
source checks protect query, mutation, copy, task-row, and detail gates, while the
screenshot seeder tests prove that fixture Goals are absent and only reserved old
fixture rows are removed. The unavailable-Goals regression scenario records the
complete product contract.

Related decision: [0712 — Gate Disabled Goals Across Release Surfaces](../decisions/0712-gate-disabled-goals-across-release-surfaces.md).
