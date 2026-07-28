# 0057 — Prefer discrete reordering in drag-heavy lists

Date: 2026-07-28

## Symptom

Dragging a top-level Mac Home task-list section did not reliably change its
position, and the extra handles made an already interactive task list feel more
complex and fragile.

## Root Cause

Section ordering introduced its own transferable payload, hover target, and
drop state inside a scrolling surface that already supports task dragging and
collapsible interactive headers. The stored ordering algorithm was sound, but
the gesture-driven integration added several failure points without a strong
need for free-form placement.

## Fix

Section drag handles, payloads, drop targets, and transient drop state were
removed. Eligible section headers now use native right-click `Move Up` and
`Move Down` commands backed by the existing stable-ID order. Today and Tomorrow
do not expose those commands.

## Prevention Rule

For infrequently changed ordering inside a drag-heavy or deeply interactive
list, prefer deterministic one-step native commands unless direct manipulation
has a clear usability advantage and is verified end to end on the real surface.
Keep persistence and ordering logic independent from the chosen interaction.

## Regression Safeguard

`HomeMacTaskListSectionOrderTests` covers one-step movement, boundary
availability, hidden-section preservation, and the Today/Tomorrow menu
exclusion. The Tasks regression scenarios require native move commands and
forbid section drag handles and drop targets. Decision
[0453](../decisions/0453-use-context-menu-actions-to-reorder-mac-home-sections.md)
records the simplified interaction.
