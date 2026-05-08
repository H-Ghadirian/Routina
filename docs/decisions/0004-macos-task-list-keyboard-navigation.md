# 0004: Support Keyboard Navigation in the macOS Task List

## Status

Accepted

## Date

2026-05-09

## Context

The macOS task list uses a custom `ScrollView` and `LazyVStack` instead of a native `List`. That gives Routina the row layout and drag behavior it needs, but it also means SwiftUI does not provide source-list keyboard selection automatically.

On macOS, users expect to select a task row and then move through adjacent rows with the Up and Down arrow keys while the detail pane follows the selection. The interaction should feel like a desktop list, not like a page jump.

## Decision

The macOS task list owns an explicit keyboard-navigation path:

- Selecting a task row focuses the task source list for keyboard handling.
- Up and Down move selection through the currently visible task IDs only, respecting filters and collapsed sections.
- Keyboard selection uses the same task selection route as pointer selection so the task detail pane updates for each selected row.
- Arrow navigation does not wrap at the top or bottom of the visible list.
- The focusable list must not draw a separate outer focus border; row selection is the visible focus affordance.
- Arrow navigation should keep the selected row visible with minimal reveal scrolling, not center the row on every key press.
- Explicit task opens from other surfaces may still request centered scrolling when they need to bring an arbitrary task into view.

The adjacent-row logic should stay in a small, testable helper instead of being embedded entirely in SwiftUI view callbacks.

## Consequences

- Future changes to the macOS task list should preserve keyboard navigation when replacing or refactoring the custom row stack.
- Filtering, section collapsing, and special task-list views must update the visible task ID sequence used by keyboard navigation.
- Tests should cover adjacent-row selection behavior, especially missing selections and list edges.
- Any visible focus decoration around the whole task list is considered a regression unless the product deliberately adopts a new focus design.
