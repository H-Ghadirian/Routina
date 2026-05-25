# 0057 Merge Support and About Settings

- **Status:** Accepted
- **Date:** 2026-05-25

## Context

Support and About were separate Settings destinations even though both are low-frequency app-meta surfaces. Keeping them split adds extra navigation weight for a small amount of content.

## Decision

Merge support contact actions and About/version diagnostics into one Settings section named Support & About. Hide the legacy Support settings section from navigation, but continue routing any persisted Support selection to the combined section.

## Consequences

- Settings has one fewer visible section.
- Users can contact support and inspect version or diagnostics from one detail screen.
- The legacy Support enum case remains available for compatibility with persisted navigation state.
