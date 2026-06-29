# 0314 Remove Status Grouping and Collapse Deadline Groups

Status: Accepted

Date: 2026-06-29

Refines: [0064 Group Home Task List by Tags](0064-group-home-task-list-by-tags.md), [0088 Support an Ungrouped Home Task List](0088-support-ungrouped-home-task-list.md), [0283 Preserve Mac Future Inner Sections](0283-preserve-mac-future-inner-sections.md)

## Context

The Task List grouping control had grown to four modes: None, Status, Deadline Date, and Tags. Status grouping duplicated information already available through badges and filters, while Deadline Date grouping made future work easier to scan by time but left date groups expanded-only inside the Mac `Future` section.

The Mac `Future` wrapper already supports independent collapse for nested tag groups. Deadline groups need the same manageability when a user has many future tasks across several dates.

## Decision

Home task-list grouping exposes `None`, `Deadline Date`, and `Tags`. The old `Status` grouping is no longer a user-facing option or the default. Legacy stored `status` grouping preferences normalize to `Deadline Date` when read or mirrored back to durable preferences.

Inside the Mac `Future` section, deadline-date groups render as independently collapsible inner groups. They keep deadline/manual-order section keys and neutral deadline styling instead of adopting tag color surfaces.

The status bucket classifier remains as compatibility logic for legacy or internal callers, but new app-facing controls should not offer Status as a grouping choice.

## Consequences

The grouping control is simpler, and Deadline Date becomes the default grouping for users who had no saved preference or an old Status preference.

Long future lists grouped by deadline can be reduced date by date without collapsing the entire `Future` wrapper.
