# 0195 Support Task Event Links

Status: Accepted

Date: 2026-06-09

Refines: [0092 Support Standalone Events](0092-support-standalone-events.md), [0194 Keep Event Capture Generic](0194-keep-event-capture-generic.md)

## Context

Users can record many kinds of events in Routina: appointments, travel, illness, holidays, conferences, family visits, and other dated happenings. Some of those events create work before or after the event, such as preparing notes, packing, following up, or recovering context.

Flattening those tasks into the event would make events feel like tasks and would confuse completion semantics. Making events joinable or attendable is a separate future event behavior, not the same as completing task work related to the event.

## Decision

`RoutineTask` stores an ordered list of linked `RoutineEvent` IDs. The task add/edit form exposes a generic `Events` section where users can link a task to existing events.

The link is contextual. Completing the task completes the task only; it does not mark the event attended, joined, done, missed, or canceled. Events remain standalone, calendar-visible records with their own title, notes, emoji, tags, time span, and optional notification.

Task-event links are preserved in task drafts, backup/import, CloudKit sharing payloads, and direct CloudKit repair paths.

## Consequences

Users log the event through the existing generic `Event` flow. If they need work connected to that event, they create or edit a task and select the event in the task form's `Events` section.

The UI can show linked events on task detail as context without adding event completion controls. Future attendable or joinable event behavior should remain event-owned behavior inside the event editor/detail model, not an implicit side effect of task completion.
