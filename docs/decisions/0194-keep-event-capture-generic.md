# 0194 Keep Event Capture Generic

Status: Accepted

Date: 2026-06-09

Refines: [0092 Support Standalone Events](0092-support-standalone-events.md), [0173 Use iOS New Tab Sheet](0173-use-ios-new-tab-sheet.md), [0070 Include Sleep in Mac Add Menu](0070-include-sleep-in-mac-add-menu.md)

## Context

Standalone events cover many different things a user may want to place on the calendar or explain in the timeline: illness, travel, holidays, appointments, conferences, family visits, and other dated happenings. Some examples are common, but promoting each example into its own top-level New action makes the capture surface harder to scan and creates unclear boundaries between examples and real product concepts.

Users need the first choice to stay understandable: choose `Event` when something happened or is scheduled and should occupy time, then describe the specific thing inside the event.

## Decision

Routina keeps one generic `Event` creation action in the iOS New sheet and macOS Home Add menu. Examples such as illness are entered as ordinary events by setting the title, optional emoji, notes, dates, notifications, and tags.

Event templates, suggestions, or remembered recent titles may be added later if they speed up entry without adding separate top-level New actions for each example.

Events remain distinct from tasks by default. If Routina later supports attendable or joinable events, that behavior should be an explicit option inside the event editor rather than a separate top-level capture type.

## Consequences

The New/Add menus stay short and concept-based: Event, Emotion, Note, Goal, Task, and session actions. Illness is not a dedicated New action.

The event editor is the place to make event-specific choices, including whether an event is just a log, a scheduled event with an optional notification, or eventually an attendable commitment.
