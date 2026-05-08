# 0001 - Maintain a Project Decision Log

Date: 2026-05-08

Status: Accepted

## Context

Routina needs a durable source of truth for important project decisions so future contributors can understand the reasoning behind architecture, conventions, product behavior, build setup, and other long-term choices before changing them.

Without a decision log, important context can live only in memory, chat history, old pull requests, or scattered comments. That makes it easier to accidentally undo decisions, repeat old debates, or change project direction without understanding the tradeoffs.

## Decision

Routina will keep project decision records in `docs/decisions/`.

Before making meaningful project changes, contributors should read `docs/decisions/README.md` and any relevant decision records.

After making a change that introduces or revises a long-term project decision, contributors should add a new decision record or supersede an existing one.

Decision records should be used for choices involving architecture, conventions, data model, dependencies, product behavior, build setup, or other project direction that future contributors should preserve or understand. They are not required for tiny fixes, copy edits, or purely mechanical cleanup.

## Consequences

Future contributors get a clear place to learn why important choices were made before changing them.

Project decisions become easier to preserve, review, and intentionally revise.

The project takes on a small documentation responsibility whenever meaningful long-term decisions are made.
