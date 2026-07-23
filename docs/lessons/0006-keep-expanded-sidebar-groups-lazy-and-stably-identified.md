# 0006 — Keep expanded sidebar groups lazy and stably identified

## Symptom

The macOS task sidebar became laggy when all top-level sections and nested
subsections were expanded and the user scrolled through the resulting outline.

## Root Cause

Only the outer task-list stack was lazy. Expanded sections nested eager stacks
for groups, child groups, and task rows, causing large off-screen subtrees to be
built. A render-time `.id` also recursively joined every task ID, walking the
complete expanded outline and replacing container identity when its string
changed.

## Fix

Nested group, child-group, and task-row stacks are lazy. Rows and groups retain
their existing semantic `ForEach` IDs, and the recursive render-identity string
and container `.id` were removed.

## Prevention Rule

An unbounded outline must stay lazy at every nesting level that can contain many
rows. Do not derive container identity by scanning descendants; use stable model
or presentation IDs on individual rows and groups.

## Regression Safeguard

The macOS performance regression suite verifies nested lazy stacks and rejects
the recursive task-group render identity.
