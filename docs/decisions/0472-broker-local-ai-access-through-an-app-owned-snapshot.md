# 0472: Broker Local AI Access Through an App-Owned Snapshot

## Status

Accepted

## Date

2026-08-04

## Context

Routina's first MCP helper opened a SwiftData container itself. That appeared to
work with the unsandboxed development app, but `--production` only changed the
store filename. The production Mac app is sandboxed, so its database lives in a
different container than the helper's ordinary Application Support directory.
The helper could therefore read development or empty data instead of the user's
production data.

Letting an external helper open the application database would also give it a
write-capable SwiftData configuration and allow post-open migrations. It would
couple a read-only integration to Routina's private schema and create concurrent
store-access risk.

## Decision

The Mac app owns all SwiftData access for local AI integrations. Local AI Access
is an explicit, device-local, default-off preference in Settings > AI
Connections. When enabled, Routina derives its normal AI task summaries and
atomically writes a versioned JSON catalog with owner-only file permissions into
the existing Routina App Group container. It refreshes after launch, activation,
and model changes; disabling access removes the catalog.
Production and development exports use different filenames even though both app
variants can access the App Group, so a development run cannot replace the
production catalog.

The MCP server reads only that exported catalog. It never imports SwiftData,
opens a Routina persistence container, starts CloudKit, or runs migrations. If
the catalog is absent, the server may launch the selected Routina app without
activating it, then reports a user-facing instruction if access is still not
enabled.

The Mac application embeds and signs a small release MCP executable under
`Contents/Helpers`. The helper maintains a lightweight schema-v1 wire model so
building it does not compile the complete Routina application package. The Mac
targets permit their controlled helper-embedding build phase to use a private
derived-data scratch directory; this does not disable the runtime App Sandbox or
hardened runtime.

All initial MCP tools remain read-only. Future create, update, or delete tools
require a separate app-owned command broker and explicit user approval design;
they must not mutate the JSON catalog or open SwiftData from the helper.

## Consequences

- Production and development data no longer depend on resolving an external
  process's Application Support directory.
- The helper cannot migrate or mutate Routina's database, and a schema change in
  SwiftData does not directly become an MCP compatibility break.
- Users can revoke future access by turning off one setting, which deletes the
  exported data. Removing the MCP client configuration is still a separate
  client-side action.
- The catalog can be briefly stale between app refreshes; responses expose its
  generation time.
- Connected AI clients may send returned task details to their own model
  provider, so Settings must disclose the exported fields and provider boundary.
