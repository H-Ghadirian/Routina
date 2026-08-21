# 0222 — Hide empty linked-task sections

Date: 2026-08-21

## Symptom

Mac Task Details showed a full Linked Tasks card with a default `Related`
picker and create/link actions even when the task had no linked tasks.

## Root Cause

The macOS `shouldShowRelationshipsSection` condition was changed to a literal
`true` while relationship suggestions were presented in the card. Suggestions
were later moved into the Link Task sheet, but the unconditional visibility
remained. The existing parity test covered the iOS progressive-disclosure rule
only.

## Fix

Mac Task Details now renders Linked Tasks only when
`store.resolvedRelationships` is non-empty. The existing Add More Details
action remains available for starting a relationship.

## Prevention Rule

Optional Task Detail sections must be driven by meaningful persisted or
resolved content. When an empty state still needs an action, keep that action
in progressive disclosure and add parity coverage for every platform that
renders the section.

## Regression Safeguard

`TaskDetailPlatformActionParityTests` now checks the macOS todo and routine
detail paths, the data-aware visibility condition, and the Add More Details
entry point. The regression scenario is recorded in
`docs/scenarios/README.md`.
