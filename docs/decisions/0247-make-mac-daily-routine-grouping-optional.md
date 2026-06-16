# 0247 Make Mac Daily Routine Grouping Optional

Status: Accepted

Date: 2026-06-16

Refines: [0202 Nest Daily Routines Under Mac Plan Today](0202-nest-daily-routines-under-mac-plan-today.md), [0210 Store Durable Preferences in SwiftData](0210-store-durable-preferences-in-swiftdata.md)

## Context

The Mac Home sidebar previously always nested daily routines under `Plan to do today` in a separately titled, collapsible `Daily Routines` group. That kept daily work visually distinct, but some users prefer a single today list where planned tasks and daily routines scan together.

Daily routines still belong to the current-day plan on Mac and still use their own manual ordering bucket. The choice is only whether the sidebar shows the nested `Daily Routines` title.

## Decision

Settings -> General on macOS exposes `Separate daily routines in task list`, defaulting off.

When the setting is off, the Mac Home sidebar shows daily routines inside `Plan to do today` without an inner title. Planned tasks and daily routines remain separate internal groups so each keeps its existing manual ordering bucket.

When the setting is on, the Mac Home sidebar restores the nested, independently collapsible `Daily Routines` group inside `Plan to do today`.

The preference is durable user-owned state and is stored with `RoutinaUserPreferences` for sync, backup, import, and reset behavior.

## Consequences

The default Mac Home sidebar has a flatter today list while preserving the option for the older nested presentation.

Existing daily and planned manual ordering keys remain compatible because the visual merge does not rewrite section keys.

iOS keeps its existing daily routine task-list presentation; this decision only changes the Mac Home sidebar layout.
