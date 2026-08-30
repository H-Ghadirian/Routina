# 0276 — Gate settings by platform and effective capability

Date: 2026-08-30

## Symptom

iOS Settings advertised Mac Planner and Calendar List behavior, described
keyboard shortcuts, and showed task- or Sleep-dependent controls when their
result could not yet be observed.

## Root Cause

The Settings destination catalog, search metadata, summaries, and detail forms
shared labels or persisted capabilities without checking whether the current
platform and current feature state had a usable consumer.

## Fix

iOS now omits Mac-only controls and Flag presentation, uses platform-specific
search and summary metadata, and gates first-task, Sleep, and battery-dependent
controls from their real availability. Hidden Mac Flag assignments remain in
the underlying task draft so an iOS save preserves cross-device data.

## Prevention Rule

A persisted or synchronized preference is not automatically a valid control on
every platform. Present a setting only where its effect can be observed, gate
dependent controls from the same capability as their consumer, and preserve
hidden cross-platform data during edits.

## Regression Safeguard

`SettingsIOSRelevanceTests`, `SettingsSectionViewSupportTests`, and
`SettingsFlagRulePresentationTests` protect platform-specific detail forms,
search metadata, adaptive prerequisites, and the separation between the
five-value persisted Flag catalog and four-value iOS presentation.

Related decision: [0703 — Keep iOS Settings Platform-Relevant and Adaptive](../decisions/0703-keep-ios-settings-platform-relevant-and-adaptive.md).
