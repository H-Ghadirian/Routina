# 0083 — Keep guided-review progress clear of navigation titles

Date: 2026-08-06

## Symptom

The guided-review task counter and progress bar could render behind the inline
navigation title, making both the destination and the progress difficult to read.

## Root Cause

The non-scrolling, full-height card stack began at the top of its navigation
destination. Unlike a scrolling container, that layout did not automatically
reserve space for the inline navigation bar.

## Fix

Pressure, Importance, and Urgency procedures now use a shared compact progress
header with explicit clearance below the navigation title. Their card content is
top-aligned, and a flexible internal spacer keeps the review actions accessible
at the card's lower edge without pushing the card below the tab bar.

## Prevention Rule

For a full-height non-scrolling destination with an inline navigation title,
reserve a dedicated header region before placing status, progress, or card
content. Do not rely on a `Spacer` to avoid navigation chrome.

## Regression Safeguard

`MissingPressureDataFeatureTests` and `MissingTaskMetadataFeatureTests` verify
that both procedure views use the shared progress header and navigation-title
clearance. The guided-review scenarios document the required separation.
