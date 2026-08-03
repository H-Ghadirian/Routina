# 0470: Keep Beta Experiments Out of Production

Status: Accepted

Date: 2026-08-03

Refines: [0214 Re-enable Adventure Map Behind Beta Toggle](0214-re-enable-adventure-map-behind-beta-toggle.md), [0215 Re-enable Mac Website Blocking Behind Beta Toggle](0215-re-enable-mac-website-blocking-behind-beta-toggle.md), [0217 Hide Board Screen Behind Beta Toggle](0217-hide-board-screen-behind-beta-toggle.md), [0218 Hide Mac Timeline Quick Filters Behind Beta Toggle](0218-hide-mac-timeline-quick-filters-behind-beta-toggle.md), [0219 Hide Stats Wins Behind Beta Toggle](0219-hide-stats-wins-behind-beta-toggle.md), [0220 Nest Sleep and Gate Mac Event and Emotion Actions](0220-nest-sleep-and-gate-mac-event-emotion-actions.md), [0221 Hide Stats Sleep Tab Behind Beta Toggle](0221-hide-stats-sleep-tab-behind-beta-toggle.md), [0224 Hide Stats Achievements Behind Beta Toggle](0224-hide-stats-achievements-behind-beta-toggle.md), [0226 Hide Mac Status Note Section Behind Beta Toggle](0226-hide-mac-status-note-section-behind-beta-toggle.md), [0237 Hide Settings Devices Behind Beta Toggle](0237-hide-settings-devices-behind-beta-toggle.md), [0243 Hide Mac Home Section Focus Timers Behind Beta Toggle](0243-hide-mac-home-section-focus-timers-behind-beta-toggle.md), [0257 Hide Task Sharing Behind Beta Toggle](0257-hide-task-sharing-behind-beta-toggle.md), [0258 Hide Linked Task Visualizer Behind Beta Toggle](0258-hide-linked-task-visualizer-behind-beta-toggle.md), [0275 Hide Places Behind Beta Toggle](0275-hide-places-behind-beta-toggle.md), [0277 Hide Notes and Away Behind Beta Toggles](0277-hide-notes-and-away-behind-beta-toggles.md), [0284 Hide Filter Query Sections Behind Beta Toggle](0284-hide-filter-query-sections-behind-beta-toggle.md), [0324 Hide Mac Stats Dashboard Controls Behind Beta Toggle](0324-hide-mac-stats-dashboard-controls-behind-beta-toggle.md), and [0466 Harden App Store Release Surfaces](0466-harden-app-store-release-surfaces.md)

## Context

Routina retained a hidden Beta Experiments panel in production. A user or reviewer could reveal it by long-pressing the version row and then enable unfinished features. Some of those features required location, microphone, or Apple Events sandbox entitlements even though the ordinary release experience did not expose matching functionality.

Hiding the panel alone is insufficient for existing installations because experimental preferences may already be stored as enabled and restored from durable preferences. Release behavior must therefore be enforced where preferences are read and written, not only in Settings presentation.

## Decision

Beta Experiments are development-build capabilities. iOS and macOS production builds do not render the Beta Experiments section, even when the hidden diagnostics section is revealed.

A shared experimental-feature policy owns the complete set of Beta Experiment Boolean preferences. Production resolves every value in that set to `false`, forces attempted writes to `false`, and normalizes previously stored values at defaults initialization. Development app variants retain the existing toggles and behavior.

Production keeps experimental user content and compatibility fields in the data model, sync, and backup formats. Disabling experiments does not delete tasks, goals, notes, places, sessions, attachments, blocking configuration, or dashboard customization data.

The macOS production entitlements omit location, audio input, and Apple Events automation. Their production purpose strings are also removed. The iOS production bundle removes location and microphone purpose strings while those experimental entry points are unavailable. Development configurations keep the permissions required to exercise and test the experiments.

## Consequences

- App Store reviewers and production users cannot reveal or reactivate unfinished experiments through persisted settings.
- Production requests only capabilities that correspond to release-visible behavior; Apple Calendar access remains declared because calendar import is a normal feature.
- Experimental data remains forward-compatible and can reappear if a feature is deliberately promoted in a future decision and the required production capability is restored.
- Any new Beta Experiment must be added to the central preference policy and must not add a production entitlement until it becomes a release feature.
