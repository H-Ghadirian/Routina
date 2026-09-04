# 0731 — Let Mac Task-Row Details Wrap

## Status

Accepted

## Date

2026-09-04

## Refines

- [0038 — Configure Home Task Row Fields](0038-configure-home-task-row-fields.md)
- [0254 — Move Mac Task Row Appearance to Home Filter Detail](0254-move-mac-task-row-appearance-to-home-filter-detail.md)
- [0418 — Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0662 — Reserve the First Mac Task-Row Line for the Title](0662-reserve-the-first-mac-task-row-line-for-the-title.md)
- [0663 — Allow Optional Multiline Mac Task Titles](0663-allow-optional-multiline-mac-task-titles.md)

## Context

Mac main task-list Appearance could mark Tags and Flags as visible while the
single secondary row compressed every label to an unreadable ellipsis. This was
especially misleading in search-only and `Hidden by flag` results, where those
labels explain why a task matched or why it is normally absent.

People still need the established compact default, but visible fields must remain
recognizable and there must be a deliberate way to trade uniform row height for
complete row context.

## Decision

Task List -> Appearance -> Task Row adds an independent `Multiline Details`
choice. It is off by default. When enabled, the Mac main task list grows each row
as needed and flows every visible planning label, Tag, assigned Flag, linked Goal,
and lifecycle status badge onto additional lines without compressing individual
labels. This applies equally to ordinary, search-only, and `Hidden by flag` rows.

When Multiline Details is off, the row preserves compact density and the status
badge's trailing placement. It shows as many complete leading labels as fit and
replaces the remaining labels with a `+N more` chip. Hover and accessibility text
identify the omitted details; the row never represents several distinct Tags or
Flags as indistinguishable ellipsized chips.

In multiline mode the status badge participates as the final item in the flowing
detail sequence instead of retaining a fixed trailing column. `Multiline Titles`
remains independent and continues to affect only the title block.

The new choice is persisted as a positive layout token beside the existing hidden
fields and multiline-title token, so existing users keep compact details and the
normal preference synchronization and backup path requires no schema migration.
Rows build the detail sequence only from their existing cached display snapshot;
the adaptive layout performs no fetches or whole-list derivation while scrolling.

## Consequences

- Turning on Tags or Flags always produces recognizable content.
- People can inspect every enabled detail without opening the task.
- Compact rows remain bounded and explain omitted context explicitly.
- Search results use the same appearance behavior as ordinary task rows.
- Title wrapping and detail wrapping can be chosen independently.
