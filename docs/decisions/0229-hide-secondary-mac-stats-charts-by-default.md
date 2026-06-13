# 0229: Hide Secondary Mac Stats Charts by Default

## Status

Accepted

## Date

2026-06-13

## Refines

- [0112](0112-show-estimated-actual-time-stats.md)
- [0113](0113-allow-stats-dashboard-reordering.md)

## Context

The macOS Stats dashboard includes detailed charts for Focus vs completed work and Estimated vs Actual time. These reports are useful for deeper review, but they make the default Stats screen denser than necessary for a first read.

The dashboard already supports hiding, restoring, and reordering reports, so default visibility can be tuned without removing the reports.

## Decision

On macOS, the Focus vs completed work and Estimated vs Actual time dashboard sections are hidden by default. They remain available in the dashboard customization flow, so users can restore them from Edit -> Add.

An explicit empty hidden-item preference means the user has chosen to show every available dashboard item, even though the first-run default hides these two sections.

## Consequences

- The default macOS Stats screen is lighter while preserving advanced reporting.
- Users who want these reports can still add them back without enabling a beta setting.
- Resetting or adding all dashboard items can represent "show all" instead of falling back to the first-run hidden defaults.
