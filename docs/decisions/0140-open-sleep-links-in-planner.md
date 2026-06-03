# 0140: Open Sleep Links in Planner

## Status

Accepted

## Date

2026-06-03

## Supersedes

- The sleep-row read-only portion of [0083](0083-open-emotion-context-links.md).

## Context

Sleep sessions are first-class records that already render as protected blocks in the day planner and as sleep rows in Timeline. Emotion logs can link to sleep sessions, but linked sleep rows were read-only because there was not a stable sleep destination yet. Users expected tapping a linked sleep session, or a sleep row in Timeline, to show the actual sleep interval instead of leaving them to hunt for it manually.

## Decision

Sleep sessions get stable `RoutinaDeepLink.sleep` URLs using `routina://sleep/<uuid>` and `routina-dev://sleep/<uuid>`.

On macOS, opening a sleep link routes Home to the Planner detail mode, selects the sleep session's start day, scrolls to the session start minute, and highlights the matching protected sleep block. Emotion detail linked-sleep rows and Timeline sleep rows use this route.

On iOS, sleep links remain parseable and route to Timeline as a fallback until the phone app has a dedicated planner destination.

## Consequences

- Linked sleep context in emotion details is actionable.
- Timeline sleep rows can reveal their planner position on macOS.
- Sleep blocks stay derived and protected; focusing a sleep session does not convert it into an editable planner block.
- Future iOS planner navigation can reuse the same `RoutinaDeepLink.sleep` identity when a planner destination exists.
