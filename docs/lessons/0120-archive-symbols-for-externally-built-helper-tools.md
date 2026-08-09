# 0120 — Archive symbols for externally built helper tools

Date: 2026-08-09

## Symptom

App Store Connect warned that the macOS archive did not include a dSYM matching `RoutinaAIMCPServer`.

## Root Cause

The helper is compiled by Swift Package Manager in a shell build phase, outside Xcode's target graph. Xcode automatically gathers dSYMs from known targets but cannot infer a companion dSYM for a manually copied executable.

## Fix

The embedding script now runs `dsymutil` on the embedded helper and writes the result to Xcode's dSYM folder whenever the build uses `dwarf-with-dsym`.

## Prevention Rule

Every externally built Mach-O executable embedded in a distributable app must contribute a dSYM generated from that exact executable to the archive's dSYM collection.

## Regression Safeguard

`AppStoreComplianceConfigurationTests.embeddedMacMCPHelperInheritsTheAppSandbox` verifies the dSYM generation path, and the release archive verification compares the helper and dSYM UUIDs. The matching scenario is recorded in `docs/scenarios/README.md`.
