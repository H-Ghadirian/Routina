# 0663: Allow Optional Multiline Mac Task Titles

## Status

Accepted

## Date

2026-08-25

## Refines

- [0038: Configure Home Task Row Fields](0038-configure-home-task-row-fields.md)
- [0254: Move Mac Task Row Appearance to Home Filter Detail](0254-move-mac-task-row-appearance-to-home-filter-detail.md)
- [0662: Reserve the First Mac Task-Row Line for the Title](0662-reserve-the-first-mac-task-row-line-for-the-title.md)

## Context

Giving the Mac main task-list title its own first line prevents status and other
labels from reducing its width, but a long title can still be truncated. Some
people prefer the most compact possible list, while others use descriptive or
technical task names whose full wording matters more than uniform row height.

## Decision

Task List -> Appearance -> Task Row offers `Multiline Titles`. It is off by
default so existing row density stays unchanged. When enabled, a long main-list
task title can wrap onto as many lines as its available width requires. The
secondary label line and any later metadata lines follow the complete title
block; they never move beside or into the title.

The choice applies only to the Mac main task list. iOS task rows and Planner
Calendar rows keep their existing layouts. The option is persisted as a
positive layout token alongside the existing Task Row hidden-field preference,
so existing visibility settings, settings backup/import, and preference
mirroring continue to use one durable value without a model migration.

## Consequences

- Compact single-line titles remain the default.
- People can trade uniform row height for complete long task names.
- Metadata remains visually subordinate and keeps the order established by
  [0662](0662-reserve-the-first-mac-task-row-line-for-the-title.md).
- Changing another Task Row field preserves the multiline-title choice.
