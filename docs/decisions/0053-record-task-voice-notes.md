# 0053: Record Task Voice Notes

## Status

Accepted

## Date

2026-05-25

## Context

Some tasks are easier to capture as spoken context than as typed notes, especially when the user is adding a task quickly or wants to preserve nuance for later. Routina already stores one optional task image directly on `RoutineTask`, while arbitrary files are stored as linked `RoutineAttachment` records.

Voice notes need the same direct task ownership as images: they are part of the task's detail surface, should be editable with the task, and should survive sync repair, sharing, backup, import, and local restore.

## Decision

Routina stores one optional task voice note directly on `RoutineTask` using external SwiftData storage for the M4A data, plus lightweight duration and creation timestamp metadata.

The add/edit task form owns recording, replacing, removing, and preview playback. The task details screen owns playback of the saved voice note. Backup packages export voice notes as task-linked attachment files instead of inline manifest data, and import restores them onto the task. CloudKit direct pull repair and task sharing include the voice-note fields.

Voice notes are reported separately from images in the iCloud usage estimate. The existing Home and Timeline media filters remain image/file focused until a dedicated voice media filter is designed.

## Consequences

- A task can carry quick spoken context without forcing users to create an external file attachment.
- Large voice data avoids manifest bloat and uses the same external-storage pattern as task images.
- Future media-filter changes should decide explicitly whether voice belongs in `Any Media`, a new `Voice` option, or both.
