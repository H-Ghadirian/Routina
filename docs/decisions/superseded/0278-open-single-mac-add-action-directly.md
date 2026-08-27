# 0278: Open Single Mac Add Action Directly

## Status

Accepted

## Date

2026-06-26

## Refines

- [0174: Do Not Restore Mac Add Task Composer](0174-do-not-restore-mac-add-task-composer.md)
- [0220: Nest Sleep and Gate Mac Event and Emotion Actions](0220-nest-sleep-and-gate-mac-event-emotion-actions.md)
- [0275: Hide Places Behind Beta Toggle](0275-hide-places-behind-beta-toggle.md)
- [0277: Hide Notes and Away Behind Beta Toggles](0277-hide-notes-and-away-behind-beta-toggles.md)

## Context

The Mac Home sidebar Add control exposes a variable set of creation actions. Beta visibility decisions can hide Event, Emotion, Note, Goal, Check In, and Away, leaving Task as the only visible default action on fresh installs.

Keeping a menu around one item makes the default Add flow require an unnecessary second click even though there is no real choice to make.

## Decision

The Mac Home sidebar `+` control computes its visible Add actions from the active feature flags. When exactly one action is visible, clicking `+` opens that action directly instead of showing a one-item menu.

When two or more actions are visible, `+` remains a menu using the existing action order and shortcuts. Opening Task through the single-action button still enters the transient Mac Add Task mode, so relaunch behavior continues to normalize Add Task back to Routines.

## Consequences

- Fresh installs can click `+` once to open full task creation.
- Users who enable optional Add actions still get the menu affordance for choosing between them.
- Future feature gates that affect the Add menu should update the shared visible-action list so the direct-button behavior remains correct.
