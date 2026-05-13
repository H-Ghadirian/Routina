# 0030: Track Device Sessions and Action Origins

## Status

Accepted

## Date

2026-05-12

## Context

Routina runs across iPhone, iPad, Mac, and Apple Watch. User-visible data mutations can happen from any of those surfaces, including watch actions that are relayed through the iPhone app. Without device-level provenance, the app cannot answer where a task was completed, where a place check-in started, or which app installations are actively participating in the user's account.

## Decision

Routina records a per-installation device session for each app surface that launches or sends sync actions. User-initiated database mutations also write a lightweight action-origin log containing the action, entity type, optional entity identifier/title, timestamp, and source device metadata.

Watch-originated actions carry their watch source metadata through the watch payload so the iPhone bridge records the Apple Watch as the actor instead of attributing the change to the relay phone.

Settings exposes active devices as a first-class section. The current device is highlighted separately from other known devices, with recent activity and mutation timestamps shown from the stored session summaries.

## Consequences

- Task creation, task edits, task completions, place check-ins, saved-place changes, focus sessions, sleep sessions, tags, and related routine log mutations can be audited by originating device.
- Device sessions are keyed by a local installation identifier stored in app shared defaults, so reinstalling an app creates a new session identity.
- Action logs and session summaries are part of the SwiftData model schema and are reset with destructive cloud/local data reset flows.
- The active devices UI is informational only for now. Remote logout or session termination is a future product decision.
