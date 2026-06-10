# 0208 Delete Standalone Notes

Status: Accepted

Date: 2026-06-11

Refines: [0060 Support Standalone Notes](0060-support-standalone-notes.md)

## Context

Standalone notes are first-class timeline evidence and can already be created, opened, tagged, searched, shared, and edited. Users also need a direct way to remove notes that are no longer wanted, especially status-style notes captured quickly from Home.

## Decision

Note detail surfaces expose a destructive Delete Note action with confirmation.

Deleting a note removes the `RoutineNote` and its owned `RoutineNoteAttachment` file rows together. The note remains a standalone data boundary: deletion does not reuse task attachment flows or convert the note into another record type.

Hosts that keep explicit note selection clear that selection after a successful delete so deleted notes do not remain selected in Mac Home or split timeline detail.

## Consequences

- Users can remove standalone notes from the same review surface where they edit and share them.
- Note file attachments do not remain orphaned after note deletion.
- Future note detail hosts should either rely on dismissal after delete or clear host-owned selection state when needed.
