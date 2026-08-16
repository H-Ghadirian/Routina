# 0589: Bound Manual iCloud Refresh

## Status

Superseded by [0590: Use Progress-Aware Incremental Manual iCloud Refresh](../0590-use-progress-aware-incremental-manual-refresh.md)

## Date

2026-08-16

## Refines

- [0523: Report Manual iCloud Refresh Honestly](../0523-report-manual-icloud-refresh-honestly.md)
- [0545: Bound iOS Foreground Focus Reconciliation](../0545-bound-ios-foreground-focus-reconciliation.md)
- [0418: Keep Whole-History Work Out of Scrolling Render Paths](../0418-keep-whole-history-work-out-of-scrolling-render-paths.md)

## Context

Settings `Sync Now`, iOS Home pull-to-refresh, and the Mac Home sync action wait
for one explicit direct CloudKit pull. That recovery pull deliberately starts
from a nil server-change token and can therefore read the complete private
SwiftData zone. CloudKit's default whole-resource timeout is seven days, so a
large, throttled, weak-network, or stalled request could keep user-initiated
progress visible long after the interaction stopped being useful.

The existing direct-pull merge begins only after the complete fetch succeeds.
That gives Routina a safe boundary at which to cancel without applying a
partial result.

## Decision

Every explicit manual full-zone pull uses user-initiated quality of service and
a 60-second request and whole-resource deadline. An independent app watchdog
uses the same deadline, cancels the CloudKit operation, and finishes the async
request even if CloudKit does not deliver a terminal callback. Canceling the
calling Swift task also cancels and finishes the CloudKit operation.

Settings and Home share recovery wording for timeouts, unavailable networks,
iCloud authentication, service throttling, and unknown failures. The wording
states that existing Routina data is safe and tells the person what to check
before retrying. Home ends pull-to-refresh, reloads its unchanged local data,
and offers `Try Again`; Settings ends `Checking iCloud for updates...` and
leaves `Sync Now` available for another attempt.

A successful manual refresh retains the truthful result defined by Decision
0523: only the direct download is confirmed, while uploads from this device
continue through system-managed background synchronization.

## Consequences

- Manual refresh can no longer own an iOS or macOS progress surface
  indefinitely.
- A request that is still legitimately processing after 60 seconds ends and
  can be retried later instead of keeping the person trapped in progress.
- Timeout and cancellation do not merge an incomplete CloudKit response, so
  the current local store remains usable.
- Full-zone repair remains reserved for deliberate manual refresh; automatic
  foreground reconciliation stays bounded to active Focus records.
