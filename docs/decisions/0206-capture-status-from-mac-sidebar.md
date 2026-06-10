# 0206 Capture Status From Mac Sidebar

Status: Accepted

Date: 2026-06-11

Refines: [0060 Support Standalone Notes](0060-support-standalone-notes.md)

## Context

Users want a low-friction way to type what they are doing at any moment, similar to sending a short chat message. The input should stay available from the Mac Home sidebar regardless of the selected sidebar tab, and each submitted update should become timeline evidence.

## Decision

The Mac Home sidebar includes an always-visible bottom status composer with a text field and send button.

Submitted status text is stored as a standalone `RoutineNote` with the typed text as the note body and a `Status` tag. The note has no separate title, so Timeline rows show the user's actual status text.

## Consequences

Status capture reuses the existing note and timeline model, avoiding a new SwiftData migration for the MVP.

Status updates appear anywhere standalone notes already appear, including Timeline search, note detail, note editing, backup/import, and CloudKit data flows.

Future dedicated current-status behavior can build on these tagged notes or supersede this record if status needs a first-class model with active/paused/done semantics.
