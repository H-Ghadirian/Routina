# 0581: Separate iOS Priority Filter Controls

## Status

Accepted

## Date

2026-08-16

## Revises

- [0534: Present iOS Priority Controls in Dedicated Sheets](0534-present-ios-priority-controls-in-dedicated-sheets.md)
- [0563: Present Importance and Urgency as Independent Task Controls](0563-present-importance-and-urgency-as-independent-task-controls.md)

## Refines

- [0537: Keep All iOS Home Filter Options in Persistent Sheets](0537-keep-all-ios-home-filter-options-in-persistent-sheets.md)
- [0548: Keep iOS Stats and Timeline Filter Details in Sheets](0548-keep-ios-stats-and-timeline-filter-details-in-sheets.md)

## Context

iOS task editing already presents Importance and Urgency as independent
judgments, but Home, Stats, and Timeline filters still exposed one combined
matrix. The matrix made changing one minimum threshold require choosing the
other again and visually separated those controls from the related Pressure
and Thinking needed filters on Home.

The stored filter cell and its matching rule remain useful: a task must satisfy
both active minimum thresholds. The presentation does not need to expose that
storage as a matrix.

## Decision

iOS Home, Stats, and Timeline Filters present Importance and Urgency as
separate compact rows inside a `Priority` section. Each row opens its own
persistent detail sheet and changes only its own minimum threshold. `All`
represents the lowest threshold for that axis, so it includes every level.

iOS Home moves its existing Pressure and Thinking needed rows into the same
Priority section. Stats and Timeline do not gain new Pressure or Thinking
needed filters.

The two independent controls continue to write the existing combined
Importance/Urgency filter cell. Matching, persistence, restoration, clearing,
and active-filter counts remain unchanged.

## Consequences

- People can change Importance or Urgency without reselecting the other axis.
- Related Home priority context is grouped in one scannable section.
- The parent filter sheets remain compact and each row still opens a dedicated
  sheet.
- Existing saved matrix thresholds remain compatible and appear as the same
  two minimum selections.
