# 0098: Support Markdown Text Editing Controls

## Status

Accepted

## Date

2026-05-29

## Context

Task comments, task notes, and standalone notes are stored and synced as plain strings. Users need more writing affordances in these areas, but changing the stored payload to rich attributed text would affect backup, import, CloudKit repair, search, sharing, and every display surface that already expects plain text.

## Decision

Routina note and comment editors expose compact formatting controls that insert Markdown-style plain text snippets for headings, bold, italic, bullet lists, checklists, quotes, code, and links.

Saved note and comment text remains plain string data. Read surfaces render that text with native Markdown parsing when possible and fall back to the original string when parsing fails.

## Consequences

- Existing persistence, backup/import, search, sync, and sharing flows continue to treat notes and comments as strings.
- Formatting remains portable and readable even outside Routina.
- Future note/comment editing improvements should preserve plain-text Markdown compatibility unless a later decision explicitly migrates the data model to rich text.
