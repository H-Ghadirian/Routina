# 0610: Expose Product Help Through Local AI Connections

## Status

Accepted

## Date

2026-08-18

## Refines

- [0472: Broker Local AI Access Through an App-Owned Snapshot](0472-broker-local-ai-access-through-an-app-owned-snapshot.md)
- [0573: Centralize User-Perspective Product Documentation](0573-centralize-user-perspective-product-documentation.md)
- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)

## Context

The first Routina MCP helper could answer questions about the person’s task
data, but it had no reliable product knowledge. A person asking “What is Task
Ladder?” or “What are the numbers above the Calendar day columns?” could
receive a generic or invented answer even though Routina already maintains the
verified meaning in its project documentation.

Repository decision and current-behavior documents are not an appropriate
runtime help source by themselves. They include implementation detail, are not
shipped as a stable user-facing contract, and cannot be assumed to exist beside
an installed app. The AI Connections screen also explained setup and privacy but
offered only one personal-task example, so it did not make product-help questions
discoverable.

## Decision

Routina maintains a compiled, privacy-safe product-help catalog shared by the Mac
app and the embedded MCP helper. Each topic has a stable ID, user-facing summary,
details, search aliases, keywords, platform and availability notes, related
topics, and example questions. The catalog begins with Task Ladder, Planner day
counts, task time meanings, Assumed done, Flags and Tags, Backlog, Focus, and
repeating tasks.

The MCP helper exposes `search_routina_help` and
`get_routina_help_topic`. These tools read only the bundled catalog, do not load
the exported task snapshot, and remain usable when `Allow read-only task access`
is off. Personal-task tools retain the opt-in snapshot boundary from Decision
0472.

Settings > AI Connections presents an in-app guide that explains setup, product
and personal-task question examples, capabilities, read-only limitations,
privacy, and recovery when the connection or snapshot is unavailable. Its
starter product questions come from the same catalog as the MCP helper.

Catalog copy is user documentation, not an automatic projection of source code
or decision records. A product change that makes a topic inaccurate must update
the catalog alongside the canonical current-behavior and user-experience
documents.

## Consequences

- Connected AI clients can explain Routina without receiving personal task data.
- The in-app examples and MCP product knowledge share one maintained source.
- Product help remains read-only and cannot become a hidden path for task
  mutation.
- The initial catalog is intentionally curated rather than exhaustive; new
  concepts need explicit user-facing copy and search aliases.
- Installed builds do not depend on repository files or network-hosted help to
  answer the supported product questions.
