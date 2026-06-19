# 0251: Require Decision Conflict Check Before Implementation

## Status

Accepted

## Date

2026-06-19

## Context

New implementation requests can conflict with existing product behavior, architecture, data model, build, or convention decisions. If an agent implements the new request immediately, it can accidentally undo an older decision or reopen a tradeoff the project already settled.

The user wants time to think when a new request contradicts an existing decision. In that case, the agent should explain the conflict briefly and wait for explicit permission before implementing the change.

## Decision

Before implementing a meaningful change, contributors and agents should check the relevant current-behavior pages and decision records for contradictions.

If the request aligns with existing decisions, work can proceed normally.

If the request appears to contradict or supersede an existing decision, the agent must pause before code changes, explain the conflict briefly, cite the relevant decision or current-behavior page, and ask for explicit permission to proceed.

After the user approves a conflicting change, the implementation should update the relevant current-behavior page and add a new decision record or supersede the old one when the change revises durable behavior.

## Consequences

- Older decisions are less likely to be accidentally undone.
- The user gets a clear checkpoint before the project changes direction.
- Intentional reversals still stay possible, but they become explicit and documented.

