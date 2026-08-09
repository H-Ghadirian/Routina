# 0526 — Identify Exact Builds in Support

Date: 2026-08-09
Status: Accepted

Refines: [0516](0516-make-support-diagnostics-copyable.md)

## Context

TestFlight can deliver several builds of the same public app version. A support
report that names only `CFBundleShortVersionString` cannot distinguish two such
installs, making a report about a bug or CloudKit issue harder to correlate
with a particular uploaded build.

## Decision

Support & About presents the public Version and the `CFBundleVersion` Build
Number as separate values on iOS and macOS. `Copy Diagnostics` includes both
labels in its privacy-safe report.

The build number is read from the installed bundle at the same time as the
version; it is not a user preference and is never inferred from a TestFlight
receipt or device activity record.

## Consequences

- Support can identify the precise uploaded binary while preserving the
  familiar public version label.
- A person can report their version and build without enabling Diagnostics.
- The support report remains free of personal data, credentials, and device
  identifiers.
