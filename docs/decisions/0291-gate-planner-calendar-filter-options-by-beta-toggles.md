# 0291 Gate Planner Calendar Filter Options by Beta Toggles

Status: Accepted

Date: 2026-06-27

Refines: [0289 Filter Planner Calendar Layers](0289-filter-planner-calendar-layers.md), [0277 Hide Notes and Away Behind Beta Toggles](0277-hide-notes-and-away-behind-beta-toggles.md), and [0220 Nest Sleep and Gate Mac Event and Emotion Actions](0220-nest-sleep-and-gate-mac-event-emotion-actions.md)

## Context

The Planner calendar filter sidebar exposes presentation-only layer toggles. Away and Sleep are controlled by the `Show Away` beta experiment, while Mac Event and Emotion actions and matching filter surfaces are controlled by the `Show Event and Emotion actions` beta experiment.

Keeping Planner filter controls visible for disabled beta surfaces makes the sidebar contradict the rest of the app. It can also leave stale hidden-layer state with no visible control after a beta surface is turned off.

## Decision

Planner calendar filters only show the Events row when `appSettingMacEventEmotionActionsEnabled` is enabled.

Planner calendar filters only show Away and Sleep rows when `appSettingAwayEnabled` is enabled. Sleep stays grouped with Away for this filter availability because Planner exposes Sleep through the Away/Sleep protected-session surface.

Unavailable beta-layer filter state normalizes to visible for rendering, hidden-layer counts, summaries, and active-filter badges. Existing records and underlying planner data remain preserved and can reappear in filter controls when the relevant beta toggle is enabled again.

## Consequences

- Turning off `Show Away` removes Away and Sleep filter choices from the Planner filter sidebar.
- Turning off `Show Event and Emotion actions` removes the Events filter choice from the Planner filter sidebar.
- Stale hidden filter values for unavailable beta layers do not keep those layers hidden without a visible control.
