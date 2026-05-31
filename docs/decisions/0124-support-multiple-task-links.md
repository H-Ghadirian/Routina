# 0124: Support Multiple Task Links

## Status

Accepted

## Date

2026-06-01

## Context

Tasks previously stored one optional URL. Real tasks often need several external references, such as a ticket, payment page, document, and dashboard. Keeping only one link forces users to choose or hide the rest in notes, where links are less structured and harder to open from task details.

## Decision

Tasks support an ordered list of sanitized HTTP/HTTPS links. `RoutineTask.link` remains the first sanitized link for backward compatibility with existing data, older backup payloads, sharing payloads, and code paths that still need one primary link. New multi-link data is stored in `linksStorage` as JSON and exposed through `RoutineTask.links`.

Task add/edit forms present links as repeatable rows. Saving sanitizes, normalizes missing schemes to `https`, removes invalid URLs, and deduplicates by URL while preserving order. Task detail surfaces render every resolved link as an openable and copyable row.

## Consequences

- Existing tasks with only `link` continue to display and migrate into the multi-link model on edit, copy, backup, or share.
- Backup/import, CloudKit direct pull repair, task sharing, iCloud usage estimates, and AI task summaries preserve the full link list.
- Backup schema version 29 includes task `links` while still accepting older backups that only contain `link`.
