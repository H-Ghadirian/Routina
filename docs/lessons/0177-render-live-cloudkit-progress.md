# 0177 — Render live CloudKit progress

Date: 2026-08-16

## Symptom

Manual iCloud refresh collected record-count progress internally, but Settings
continued showing the same circular spinner and `Checking iCloud for
updates...` text throughout the download. Home likewise exposed only its
ordinary refresh affordance. A working long refresh therefore still looked
indistinguishable from an endless loop.

## Root Cause

The Settings reducer accepted each diagnostics progress message, but the
visible status helper returned a fixed in-progress string before consulting
that live message. The views also used only a compact circular indeterminate
indicator. CloudKit zone changes provide record callbacks but no total pending
record and deletion count, so a truthful completion percentage was not
available.

## Fix

iOS and macOS Settings and Home now render a linear activity indicator and the
live manual-refresh status. The exact received-item count appears after the
first item and updates every 25 items, then changes to the applying phase when
the download finishes. Routina deliberately does not display a fabricated
percentage.

## Prevention Rule

A progress surface must render the live progress state instead of allowing a
generic in-progress branch to mask it. Use a percentage only when the platform
provides a reliable numerator and denominator; otherwise expose truthful
activity, phase, and count.

## Regression Safeguard

`SettingsSectionViewSupportTests.cloudSyncProgressShowsTheLatestReceivedItemCount`
protects live status selection, and
`SettingsSectionViewSupportTests.cloudSyncViewsUseLinearProgressBars` protects
the iOS and macOS visual progress surfaces.
`CloudKitSyncDiagnosticsTests.manualRefreshResetsInactivityOnProgressAndSavesTokenOnlyAfterMerge`
also protects the 25-item reporting interval. The Manual iCloud Refresh
scenario records the no-fabricated-percentage requirement.
