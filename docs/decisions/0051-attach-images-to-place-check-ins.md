# 0051: Attach Images to Place Check-Ins

## Status

Accepted

## Date

2026-05-25

## Context

Place check-ins are increasingly used as timeline evidence for where time was spent. Some check-ins need visual evidence or memory cues, such as a receipt, a whiteboard, a room setup, or a scene from the place.

Task images already use compressed image data and backup-package attachment files so routine data stays reasonably small. Place check-in images need the same durability without turning a check-in into a task or a file attachment.

## Decision

Routina stores one optional compressed image directly on each `PlaceCheckInSession` using external SwiftData storage. The editable Places check-in history is the primary place to add, replace, or remove that image.

Place check-in images are included in backup packages as attachment files linked to the place check-in session, then restored with the session on import. Timeline media filtering treats image-bearing place check-ins as image media for `Any Media` and `Image`; `File` remains limited to task file attachments.

## Consequences

- Place check-ins can carry visual evidence without creating a separate task or mutating saved places.
- Backup and import preserve image evidence while keeping the manifest from carrying large base64 image payloads.
- The shared media filter now includes non-task image evidence for place check-ins, but file filtering remains task-file only until place sessions gain file attachments.
