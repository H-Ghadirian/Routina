# 0121 — Decode partial CloudKit failures without copying user data

Date: 2026-08-09

## Symptom

Diagnostics reported `CKError.partialFailure` for a manual CloudKit export, but did not identify the failing child operation.

## Root Cause

The diagnostic code attempted to cast CloudKit's Objective-C partial-error dictionary directly to a Swift generic error dictionary. That bridge can fail, and the report lost the per-item details Apple provides for a partial failure.

## Fix

Diagnostics now use CloudKit's typed partial-error property with an Objective-C dictionary fallback. They report the underlying error code for up to three items and redact each raw item identifier as a stable SHA-256 fingerprint.

## Prevention Rule

Never treat a partial CloudKit error as diagnosable from its outer code alone. Preserve actionable child error codes, but hash item identifiers and never copy record names, fields, or localized child messages into support diagnostics.

## Regression Safeguard

`CloudKitSyncDiagnosticsTests.partialFailureDescribesAnonymizedRecordSpecificErrors` verifies that partial errors include a child code and anonymized record label while excluding the raw record name. The matching scenario is recorded in `docs/scenarios/README.md`.
