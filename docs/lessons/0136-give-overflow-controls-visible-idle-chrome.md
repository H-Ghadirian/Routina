# 0136 — Give overflow controls visible idle chrome

Date: 2026-08-11

## Symptom

The Mac Task Detail vertical-overflow control looked like an empty dark gap
until opened, then changed into an oversized blue circle that did not match the
adjacent toolbar buttons.

## Root Cause

The control deliberately had no idle container and rendered its active state
as a separately sized circular surface, while the neighboring toolbar actions
used rounded-rectangle chrome at the full hit area.

## Fix

The overflow trigger now shares the same rounded toolbar chrome as the link,
edit, and close actions. Its open state adds only a restrained accent fill and
border.

## Prevention Rule

An icon action in a compact, visually grouped toolbar must have visible idle
chrome that matches its full interactive hit area; its active state may tint
that surface but must not switch to an unrelated shape.

## Regression Safeguard

`TaskDetailPlatformActionParityTests.macFullDetailGroupsSecondaryTaskActionsInAnOverflowMenu`
asserts that the vertical overflow symbol uses the shared active toolbar chrome
and does not reintroduce a circular surface.
