# 0226 — Scope Section-Name Uniqueness to the Workspace Surface

Date: 2026-08-23

## Symptom

Mac Settings -> Sections rejected a new Backlog section with the message
`A section with this name already exists.` when the same title was already used
by a Main task list section.

## Root Cause

The shared section sanitizer, upsert operation, and rename operation keyed title
uniqueness only by parent ID. For top-level sections that collapsed Radar and
Backlog into one namespace, even though Settings exposed them as independent
destinations.

## Fix

Top-level title scopes now include the section surface. Subsections continue to
use their parent ID (and inherited surface), and the same scope is applied by
sanitization, creation, and rename validation.

## Prevention Rule

Whenever a shared catalog is presented as separate destinations, include the
destination in every sibling-uniqueness key and validate the same scope at all
mutation and persistence boundaries.

## Regression Safeguard

`HomeCustomTaskSectionStorageTests` verifies that identical top-level titles
can coexist across Radar and Backlog, while same-surface duplicates are still
deduplicated and cross-surface renames are allowed. The Mac Settings Sections
scenario documents the same contract.
