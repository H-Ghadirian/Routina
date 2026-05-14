# 0041: Filter Home Tasks by Goal Presence

## Status

Accepted

## Date

2026-05-14

## Context

Goals are a primary way to organize meaningful work, but the Home list could only search for goal names. Users need a direct way to separate tasks that are attached to a goal from tasks that still need goal assignment.

## Decision

Home task filters include a goal presence filter with three states: All, Has Goal, and No Goal. The filter is part of the shared Home filter state, persists in temporary view state and per-tab snapshots, and applies to both visible and archived task list sections.

The setting is platform-neutral: iOS exposes it in the Home filters sheet, and macOS exposes it in the Home filters sidebar.

## Consequences

- Users can quickly find tasks that need a goal without relying on manual search conventions.
- Goal presence behaves like the existing pressure, state, tag, and place filters when switching Home task tabs.
- Future goal-specific filters should build on this shared Home filter state instead of adding platform-only UI state.
