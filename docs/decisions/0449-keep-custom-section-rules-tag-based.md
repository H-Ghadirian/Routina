# 0449: Keep Custom Section Rules Tag-Based

Date: 2026-07-28

Status: Accepted

Refines: [0411 Manage Custom Task Sections in Settings](0411-manage-custom-task-sections-in-settings.md), [0440 Treat Day Planning Sections as Additive](0440-treat-day-planning-sections-as-additive.md)

## Context

Settings originally let every custom Mac task section claim unassigned tasks
through `Planned today`, `Planned tomorrow`, or tag rules. Day planning is now
an additive projection with dedicated built-in `Today` and optional `Tomorrow`
sections, so duplicating those same dates as configurable custom-section rules
adds overlapping placement controls without adding a distinct organization
signal.

Removing only the visible toggles would leave previously enabled rules active
without any way to inspect or disable them.

## Decision

Custom Mac task-section automation is tag-based. Settings -> Sections keeps the
tag rule editor and no longer offers `Planned today` or `Planned tomorrow` rule
options for any custom super section.

The custom-section rule model no longer evaluates planned dates. Legacy
persisted `enabled` rule values decode as inert compatibility data and are
omitted when the section catalog is next encoded. Configured tag names continue
to decode, encode, and route unassigned matching tasks as before.

Manual custom-section and subsection assignments remain unchanged. The built-in
additive `Today` and optional `Tomorrow` planning sections also remain
unchanged.

## Consequences

- Planned dates cannot automatically route a task into a custom section.
- Previously saved planned-day rules stop affecting task placement immediately
  instead of becoming hidden active behavior.
- Tag rules remain the only automatic custom-section placement rule.
- Planning and explicit custom assignments remain independent stored
  dimensions.
