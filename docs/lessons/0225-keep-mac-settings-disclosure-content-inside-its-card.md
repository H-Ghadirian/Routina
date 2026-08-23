# 0225 — Keep Mac Settings disclosure content inside its card

Date: 2026-08-23

## Symptom

Expanding or collapsing a custom section editor in Mac Settings showed
intermediate frames where controls faded and moved outside their rounded card.

## Root Cause

The editor used a combined opacity and move-from-top insertion/removal
transition while the parent card animated its changing layout height. SwiftUI
therefore animated both the content transition and the container geometry.

## Fix

The editor now uses an identity transition, so only the card layout height
animates, and the card clips its rounded bounds during the change.

## Prevention Rule

For expandable card content, do not combine directional/opacity transitions
with an animated parent height unless the content is intentionally allowed to
move independently. Prefer a single layout animation and clip content to the
card surface.

## Regression Safeguard

`MacWorkspaceNavigationSourceTests.macSectionSettingsSeparatesRadarAndBacklogCatalogs`
asserts that the section editor uses an identity transition and clipped rounded
bounds, and rejects the old move-plus-opacity transition. The Settings scenario
also requires controls to remain inside the card during disclosure.
