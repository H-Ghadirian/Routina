# 0190 — Declare exact optional files to Xcode script sandboxes

Date: 2026-08-16

## Symptom

An iOS development build failed after a valid ignored Firebase configuration
was added. The copy script reported that the plist's bundle ID was the text of
`PlistBuddy`'s missing-file message instead of `ir.hamedgh.Routinam.dev`.

## Root Cause

The Xcode build phase declared `Config/Firebase` as a script input. With user
script sandboxing enabled, access to that directory did not grant the script's
`PlistBuddy` subprocess access to ignored plist files inside it. The repository's
source-level tests verified the script and filenames but not the build phase's
sandbox input contract.

## Fix

Each iOS and macOS app target now declares its exact variant-specific Firebase
plist as the copy phase input. The script still treats a genuinely absent
configuration as an intentional no-op.

## Prevention Rule

When a sandboxed Xcode build script reads a known file, declare that exact file
as an input. Do not assume that declaring its containing directory recursively
grants subprocess access to the file.

## Regression Safeguard

`CrashlyticsConfigurationTests.configurationCopyDeclaresExactInputsForXcodeScriptSandboxing`
requires the production, iOS development, and macOS development plist paths in
their platform projects and rejects the former directory-only input.
