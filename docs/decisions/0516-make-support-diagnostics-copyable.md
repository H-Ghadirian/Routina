# 0516 Make Support Diagnostics Copyable

Status: Accepted

Date: 2026-08-09

Refines: [0515 Report Signed CloudKit Environment in Diagnostics](0515-report-signed-cloudkit-environment-in-diagnostics.md)

## Context

Support diagnostics are often needed from another person's device. Reading several rows from a screenshot is error-prone and may omit the operating-system version that helps distinguish a device-specific platform or CloudKit behavior.

## Decision

The hidden Support & About Diagnostics section shows the current operating-system name and version on iOS and macOS. It also offers a native `Copy Diagnostics` action with a copy icon. The action copies one labelled plain-text report containing app version, operating system, configured data mode, iCloud container, signed CloudKit environment, last CloudKit event, and push status.

The report contains operational metadata only. It must not include task content, account identifiers, device tokens, backups, or credentials.

## Consequences

- A customer can paste one complete diagnostic report into a support conversation without transcribing rows or taking a screenshot.
- Support can relate CloudKit behavior to both the installed app and operating-system version.
- The copy action does not transmit data; it writes only the report to the local system clipboard.
