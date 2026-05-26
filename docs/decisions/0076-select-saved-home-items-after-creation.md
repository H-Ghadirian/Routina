# 0076: Select Saved Home Items After Creation

## Status

Accepted

## Date

2026-05-26

## Context

Home creation flows for tasks, goals, and standalone notes use different surfaces on macOS. Saving could close the creation surface without making the new item the visible detail selection, which forced users to search for the thing they had just created.

## Decision

After a successful save, Home routes to the newly saved entity's detail and synchronizes the visible sidebar row with that entity.

- Tasks return to the routines/todos sidebar, select the saved task, open its detail state, and clear visibility filters/search state that could hide the row.
- Goals close the inline editor, clear goal search, and select the saved goal.
- Notes close the inline note editor, open Timeline in Notes mode, clear timeline search/filters, and select the saved note row.

## Consequences

- Creation flows now land on confirmation through the actual detail screen instead of returning to an unrelated prior selection.
- Sidebar search and filters may be cleared after save so the selected row is visible immediately.
- Future Home creation surfaces should treat post-save navigation as part of the save contract, not as optional view cleanup.
