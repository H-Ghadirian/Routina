# 0135: Show Today Focus Widget

## Status

Accepted

## Date

2026-06-02

## Context

Mac users can already see a current focus timer widget and broad Routina stats, but there is no dedicated widget for the day's accumulated focus time. The useful glance is a simple total that stays current while focus is actively running, including task, unassigned, and board focus.

## Decision

Add a macOS-only Today Focus widget to the Routina widget bundle. The widget reads the existing app-group widget stats payload and shows today's focus total, session count, and a live state when an unpaused focus session is active.

The shared widget stats payload now includes today's focus seconds, today's focus session count, and an optional timestamp from which an active focus session should increment. Task, unassigned, and board focus contribute the portion overlapping the reference day, capped by each session's persisted active duration. Active focus keeps incrementing while unpaused.

## Consequences

- macOS users can add a focused widget for today's total focus time without opening Stats.
- The existing stats widget remains unchanged visually while sharing the expanded payload.
- Widget stats refreshes now fetch focus history and reload both stats widgets on macOS when the payload changes.
- Cross-midnight sessions are represented as a practical day-span total, but exact pause placement across midnight remains limited by the current aggregate pause-duration storage.
