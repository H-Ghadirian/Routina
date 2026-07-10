# 0363: Gate Mac Plan Tomorrow Menu Item

Date: 2026-07-10

Status: Accepted

Refines: [0350 Add Optional Mac Tomorrow Task Section](0350-add-optional-mac-tomorrow-task-section.md)

## Context

Decision [0350](0350-add-optional-mac-tomorrow-task-section.md) made the `Tomorrow` task-list section optional and defaulted it off, but the Mac row context menu still exposed `Plan to do -> Tomorrow` while the section was hidden. That let users create tomorrow-planned work even though the matching top-level review surface was disabled, leaving the result to appear under `Future`.

## Decision

The Mac task row context menu exposes `Plan to do -> Tomorrow` only when Settings -> General -> Task List -> `Show Tomorrow section` is enabled.

When the setting is off, the `Plan to do` submenu keeps `Today`, `Choose Date...`, and any relevant clearing or `Not today` actions, but omits the direct `Tomorrow` shortcut. Users can still choose a specific date manually through `Choose Date...`.

## Consequences

- The visible planning shortcuts now match the visible top-level task-list sections.
- Turning off `Show Tomorrow section` hides both the `Tomorrow` section and the direct `Tomorrow` planning shortcut.
- Existing tasks already planned for tomorrow still remain valid data and continue to appear through `Future` while the section is off.
