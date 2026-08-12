# 0554: Correlate Debug Stalls With Safe Interaction Trails

## Status

Accepted

## Date

2026-08-12

## Refines

- [0553: Record Debug Performance Symptoms for Support](0553-record-debug-performance-symptoms-for-support.md)

## Context

The initial Debug performance profile shows when CPU, memory, or main-thread
delays were unhealthy, but it cannot distinguish a startup delay from a person
scrolling Home, changing a filter, opening task details, or manually syncing.
That makes a shared file less useful for selecting the next focused
reproduction.

Arbitrary analytics labels, raw input, task titles, and filter values would
make that context unsafe to hand off. Raw tap events would also be noisy and
would not communicate the semantic action relevant to diagnosis.

## Decision

Debug performance profiles record a bounded interaction trail using a closed
set of fixed categories: navigation, Mac sidebar navigation, task-list/search/
timeline scrolling, search state without its query, filter changes without
their values, task lifecycle actions, creation entry points, and manual
sync/backup actions.

The recorder accepts only a fixed enum. Unknown tab and sidebar values are
rejected, and repeated interaction categories are coalesced in a short window.
Each main-thread stall includes up to three safe interaction categories that
occurred in its preceding ten seconds.

The profile must never contain task names, record IDs, search text, tag or
filter values, form content, locations, account data, credentials, screenshots,
screen recordings, or raw system input. This remains a bounded Debug handoff
artifact, not an Instruments replacement.

## Consequences

- A shared profile can attribute a delay to a broad action, such as Home-list
  scrolling or a Timeline filter change, without exposing the person's data.
- Investigators can select a narrower Instruments reproduction path from the
  symptom report, but still need Instruments for the responsible call stack.
- New diagnostic interaction points must add a fixed category rather than
  passing user-provided text into the profiler.
- The interaction trail is bounded to 240 events and is deliberately less
  detailed than product analytics or event recording.
