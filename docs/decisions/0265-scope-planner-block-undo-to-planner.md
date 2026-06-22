# 0265: Scope Planner Block Undo to Planner

- Status: Accepted
- Date: 2026-06-21

## Context

Planner block resizing and repositioning are calendar-editing actions that users expect to reverse with Command-Z. The generic macOS undo stack can technically reverse SwiftData edits, but planner blocks also carry visible calendar context: undoing a move or resize should take the user back to the affected day and time so the reversal is understandable.

Planner block undo should not behave like a delayed global data reversal. If the user leaves the Planner for Details, Places, Board, Timeline, Settings, or another Home surface, a later Undo should not unexpectedly move an old planner block.

## Decision

 Planner block resize and reposition actions register a native macOS undo item only while the Planner surface is active. Planner block persistence avoids SwiftData's automatic global undo registration for those block records, and the Planner owns a scoped undo target that is cleared when Home leaves the Planner surface.

Applying planner undo restores the affected day-plan block snapshots, selects the restored block, navigates the calendar to the restored block's date, scrolls to its start time, and highlights the block.

The macOS Edit menu may route undo through a responder chain that does not discover scoped Planner block edits reliably. Routina's command layer may therefore invoke the active Routina native `UndoManager` directly for non-text undo/redo commands, while text editing continues to use AppKit's text undo path.

## Consequences

- Command-Z works for recent planner block resize and reposition actions while the user remains in Planner.
- Leaving Planner clears planner-block undo so later global Undo commands cannot unexpectedly revert hidden calendar edits.
- Planner undo remains integrated with native macOS undo/redo rather than adding an app-specific visible history stack.
