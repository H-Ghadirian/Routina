# 0078 — Do not resolve sandboxed app data from external processes

Date: 2026-08-04

## Symptom

The Routina MCP server was started with `--production`, but AI questions returned
data from the Routina development app rather than the production Mac app.

## Root Cause

`--production` changed Routina's store filename but not the filesystem container
used by the helper process. The production app is sandboxed and stores SwiftData
inside its application container, while an external command-line process resolves
Application Support from the user's ordinary home directory. The helper also
created a write-capable SwiftData container that could run post-open migrations,
despite exposing read-only tools.

## Fix

The app now exports an opt-in, versioned read-only task snapshot to its App Group,
with distinct filenames for production and development.
The MCP helper reads and filters only that file and no longer links Routina's
persistence package or opens SwiftData. The Mac app embeds the helper and offers
a copyable setup command in AI Connections settings.

## Prevention Rule

Never derive a sandboxed app's private database path from a separately launched
process. External read-only integrations must consume an app-owned export or use
an app-owned IPC broker; only the app process may open Routina's SwiftData store.

## Regression Safeguard

`RoutinaAIReadOnlySnapshotStoreTests` verifies snapshot versioning and asserts
that the MCP server source does not reference SwiftData or
`PersistenceController`. Query-service coverage verifies that exported summaries
can be filtered without reopening a model context, and the Mac build verifies
that the helper is embedded.
