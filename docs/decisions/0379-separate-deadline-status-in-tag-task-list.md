# 0379 Separate Deadline Status in Tag Task List

Status: Accepted

Date: 2026-07-13

Refines: [0064 Group Home Task List by Tags](0064-group-home-task-list-by-tags.md), [0314 Remove Status Grouping and Collapse Deadline Groups](0314-remove-status-grouping-and-collapse-deadline-groups.md), [0347 Split Mac Future Tag Groups By Task Kind](0347-split-mac-future-tag-groups-by-task-kind.md)

## Context

Tag grouping keeps Mac `Future` work organized by area, project, or context, but urgent rows can be buried inside individual tag groups. Deadline Date grouping already promotes `Missed`, `Overdue`, and `Due Soon` groups ahead of later date buckets, which makes time-sensitive work easier to scan.

Users should be able to keep Tags as their primary organization while still seeing urgent work called out first.

## Decision

Mac Home adds a persistent Task List Sort option, visible when grouping is `Tags`, to show deadline-status groups separately.

When enabled, tag grouping first renders `Missed`, `Overdue`, and `Due Soon` `Future` child groups using the same neutral collapsible treatment and stable section keys as Deadline Date grouping. Remaining on-track rows continue to render under their first tag or `No Tags` group. `Done Today`, when visible in the active list, remains a separate status group after the tag groups.

The option is stored with app task-list preferences and included in user-preference backup and restore. It is independent from the existing `Separate todos and routines` tag option, which still applies only inside mixed tag or untagged groups that remain after the deadline-status split.

## Consequences

Users can keep tag grouping without losing the overdue/due-soon scan affordance from Deadline Date grouping.

Rows lifted into deadline-status groups use status section manual-order keys while on-track tag rows keep tag manual-order keys.
