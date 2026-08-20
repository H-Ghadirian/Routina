# 0214 — Preserve Quick Add preview state across compatible reparses

Date: 2026-08-20

## Symptom

After editing a fetched link title or choosing a reminder in Mac toolbar Quick Add, typing another character or adding a tag reset the preview. Link metadata fetched again, the edited title disappeared, and the reminder returned to `No reminder`.

## Root Cause

The search text change handler treated every raw-string change as a new task. It unconditionally reset all preview-owned state, and the metadata task identity included the complete query instead of the URL being fetched.

## Fix

Quick Add now compares consecutive parsed drafts before reconciling the preview. Continuous edits, the same parsed task name, and an unchanged primary URL preserve user-owned title and reminder state. The metadata task is keyed only by the URL, while a cleared or meaningfully replaced task and a changed or removed link start fresh.

## Prevention Rule

Do not use a live parser input string as the identity of interactive state derived from that parser. Give network work the identity of the resource it fetches, and reconcile user-owned controls by semantic draft continuity rather than resetting them on every keystroke.

## Regression Safeguard

`RoutinaQuickAddParserTests` covers adding and starting a tag, a one-character edit, replacement tasks, and changed links. The Mac source regression requires the toolbar to use semantic reconciliation, URL-only metadata identity, and no unconditional reminder reset in the search text change handler.
