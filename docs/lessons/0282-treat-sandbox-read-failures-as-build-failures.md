# 0282 — Treat sandbox read failures as build failures

Date: 2026-09-01

## Symptom

The iOS production archive reported a stale CloudKit Production schema even
though the acknowledged manifest was current and CloudKit Dashboard had no
changes to deploy. The build log first showed that `awk` could not open a model
source and `grep` could not read the manifest, then emitted integer-expression
errors while constructing the misleading schema message.

After that phase was repaired, the same archive reached Crashlytics symbol
upload and the sandbox denied Firebase's `run` executable.

## Root Cause

The Xcode build phase declared the model and CloudKit directories as inputs,
but user-script sandbox access to a directory did not grant subprocesses access
to its child files. The schema-generation pipeline also observed only its final
sort command's status, hiding the failed `awk`; `grep || true` similarly turned
a manifest permission failure into an empty field count.

The Crashlytics upload phase separately declared a package-checkout path based
on the normal build directory depth. Archive nests `BUILD_DIR` three levels
deeper, so the declared input did not match the `run` path resolved by the
wrapper; `upload-symbols` was not declared as an executable input either.

## Fix

Both production projects now declare the manifest exactly and share an Xcode
input file list containing every SwiftData model source. The guard checks each
model extraction, manifest comparison, and manifest count operation and stops
with an explicit sandbox-input error when any read fails.

Crashlytics upload phases now declare `run` and `upload-symbols` at both the
normal-build and archive-relative package paths.

## Prevention Rule

For a sandboxed build script, declare every subprocess-readable file as an
exact input. Never let a pipeline or unconditional success fallback translate
an input/output failure into a valid domain value or a misleading domain error.

## Regression Safeguard

`AppStoreComplianceConfigurationTests.productionArchivesDeclareExactCloudKitInputsForXcodeScriptSandboxing`
requires the shared file list to exactly match all Swift files under
`SharedCore/Models` and requires both projects to use it with the exact
manifest. `productionSchemaGuardStopsAfterSandboxReadFailures` protects the
guard's explicit error paths.
`CrashlyticsConfigurationTests.symbolUploadDeclaresNormalAndArchivePackageExecutablesForSandboxing`
requires every iOS and macOS upload phase to preserve both exact executable
paths.

Related decision: [0525 — Gate TestFlight Archives on CloudKit Schema Deployment](../decisions/0525-gate-testflight-archives-on-cloudkit-schema-deployment.md).
