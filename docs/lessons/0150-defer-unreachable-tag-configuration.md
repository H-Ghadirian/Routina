# 0150 — Defer unreachable tag configuration

Date: 2026-08-12

## Symptom

iOS Settings -> Tags offered an `Add to quick filters` button even though the
app had no visible quick-filter shortcut surface to use the selected tag.

## Root Cause

The preference and Home filtering action were implemented ahead of their
discoverable user-facing destination, but Settings exposed their configuration
as if the feature were complete.

## Fix

The configuration button and quick-filter count are hidden until the feature
has a usable Home shortcut surface. The retained implementation and its
completion requirements are recorded in Product Debt 0002.

## Prevention Rule

Only expose configuration after its corresponding action is both discoverable
and immediately usable in the app.

## Regression Safeguard

`SettingsTagPresentationTests.savedTagOptionsAreRevealedOnlyForTheSelectedTag`
rejects quick-filter controls in the iOS saved-tag settings view. Product Debt
0002 defines the required end-to-end coverage before the feature can return.
