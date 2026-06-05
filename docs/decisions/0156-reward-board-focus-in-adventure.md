# 0156: Reward Board Focus in Adventure

## Status

Accepted

## Date

2026-06-05

## Refines

- [0150: Add Mac Adventure Progression MVP](0150-add-mac-adventure-progression-mvp.md)

## Context

Adventure rewards ordinary tasks, focus, sleep, Away, captures, goals, and place check-ins, but board work was not visible as its own coin source. Board focus already exists as a distinct protected session type and is part of Routina's planning loop, so hiding it inside generic focus makes the game economy less clear.

## Decision

Mac Adventure treats filled board focus blocks from `SprintFocusSessionRecord` as their own reward source. Task/unassigned `FocusSession` blocks keep their existing reward value, while board focus blocks earn a slightly higher reward because they represent focused work inside a chosen board/sprint context.

Board focus blocks count toward total rewarded actions and Adventure XP/stage progress just like other rewarded actions. The Earn Coins guide names board focus separately so users can see that using the Board can progress Adventure.

## Consequences

- Board work is visibly rewarded without adding a new persisted economy model.
- Existing task focus rewards remain intact, but the previous combined focus source is now split into task focus and board focus.
- Users with board focus history may see slightly higher total coins because board focus blocks earn their own rate.
