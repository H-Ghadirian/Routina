# 0084: Include Personal Records in Stats Summary

## Status

Accepted

## Date

2026-05-27

## Context

Stats originally focused on routine activity, task creation, focus time, tags, and optional Git activity. Routina now also has standalone emotion logs, notes, and goals, so the Stats dashboard should represent more of the user's captured life context without turning those records into automated insight summaries.

## Decision

Stats summary cards include emotion, note, and goal metrics alongside task and focus metrics.

Emotion and note counts follow the selected Stats date range. The emotion card can show logged days and average intensity, and the note card can show media-bearing notes. The goal card shows active and archived goal state with a created-in-range count.

These records are summary cards rather than generated insight sections or routine/task-dependent stats.

## Consequences

- Stats reflects standalone emotions, notes, and goals even when no routine has been completed.
- Emotion stats stay factual and compact instead of producing interpretation or insight copy.
- Stats data refresh flows must load emotion logs, notes, and goals on both iOS and macOS.
