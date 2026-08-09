# 0522: Anonymize CloudKit Partial Failure Diagnostics

Status: Accepted

Date: 2026-08-09

Refines: [0516 Make Support Diagnostics Copyable](0516-make-support-diagnostics-copyable.md)

## Context

CloudKit reports a failed subset of an import or export as `partialFailure`. The outer error does not identify whether the underlying cause is a rejected record, an asset problem, a quota issue, or a retryable service condition.

The per-item error map is actionable for support, but raw record identifiers and error descriptions can reveal personal or app data when copied to another person.

## Decision

For a CloudKit partial failure, diagnostics report the total failed-item count and up to three actionable child error codes. Each item is labelled with its kind and a short SHA-256 fingerprint of its identifier. The report omits the raw identifier, record name, record fields, and localized child-error text.

When a custom-zone batch includes secondary `batchRequestFailed` entries, diagnostics prefer the non-batch child failures so the root cause is visible.

## Consequences

- Support can distinguish per-record rejection, quota, asset, conflict, and retryable failures from a generic outer error.
- A copied report remains safe to share because it contains no task content or raw CloudKit identifiers.
- The same failed item can be correlated across repeated reports by its stable fingerprint.
