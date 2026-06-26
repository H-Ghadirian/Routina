# 0284 Hide Filter Query Sections Behind Beta Toggle

- Status: Accepted
- Date: 2026-06-26
- Refines: [0041 Filter Home Tasks by Goal Presence](0041-filter-home-tasks-by-goal-presence.md), [0108 Show Stats Outcome Mix](0108-show-stats-outcome-mix.md), and [0210 Store Durable Preferences in SwiftData](0210-store-durable-preferences-in-swiftdata.md)

## Context

Advanced query filtering is implemented for Home and Stats filters, but the Query builder adds a dense expert control to otherwise ordinary filter panels. Routina already keeps optional or advanced surfaces behind Support & About -> Beta Experiments so fresh installs stay quieter while implemented functionality remains available.

## Decision

Home and Stats filter Query sections are hidden by default behind Support & About -> Beta Experiments -> `Show filter query sections`.

When the toggle is off, the Query editor sections are not shown in iOS Home filters, iOS Stats filters, the Mac Home filter detail, or the Mac Stats filter sidebar. Existing advanced query state, filter matching, and active filter summaries remain compatible so query text is preserved and clearable if already active.

The preference is durable and user-owned, stored as `appSettingFilterQuerySectionsEnabled`, mirrored into `RoutinaUserPreferences`, and included in backup/import behavior.

## Consequences

- Fresh installs do not show advanced query builder sections in task or stats filter panels.
- Users who rely on query syntax can opt back in from Beta Experiments without losing existing query filter state.
- Future filter surfaces that expose the shared advanced query builder should respect the same preference unless they intentionally define a different query entry point.
