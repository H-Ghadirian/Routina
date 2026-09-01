# 0281 — Sanitize downloaded deployment inputs after copying

Date: 2026-08-31

## Symptom

App Store Connect rejected the macOS package with error 91109 because
`Routinam.app/Contents/Resources/GoogleService-Info.plist` carried the
`com.apple.quarantine` extended attribute.

## Root Cause

The ignored Firebase configuration had been downloaded in a browser and was
quarantined on disk. The custom Xcode build phase used a plain `cp`, which
propagated that metadata into the signed app bundle even though the plist's
contents and bundle ID were valid.

## Fix

The shared Firebase configuration copy phase now deletes
`com.apple.quarantine` from the destination plist immediately after copying it
and before code signing. The behavior applies to both iOS and macOS production
and development app targets.

## Prevention Rule

Treat downloaded deployment inputs as carrying filesystem metadata as well as
file contents. When a custom build phase embeds one in a distributable bundle,
explicitly remove attributes that the distribution service forbids at the
destination boundary before signing.

## Regression Safeguard

`CrashlyticsConfigurationTests.configurationCopyRemovesQuarantineFromBundledPlist`
requires the copy phase to retain the sanitization command. Release verification
also audits the final app bundle recursively for `com.apple.quarantine` before
upload.
