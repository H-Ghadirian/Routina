# 0130: Block Manual Completion Until Optional Checklists Are Done

## Status

Accepted

## Date

2026-06-01

## Context

[0069](0069-support-optional-task-checklists.md) made checklist items available on ordinary routines and one-off todos as optional progress details. Those optional checklist items do not complete a task by themselves, but allowing the main Done action while items remain unchecked can make the checklist feel advisory instead of meaningful.

## Decision

Tasks with optional checklist items cannot be manually marked done until every checklist item is checked.

Checklist-driven routine formats keep their existing behavior: checklist-format routines complete through checklist item completion, and runout routines update due checklist items instead of using the normal manual Done path.

## Consequences

- Optional checklists now act as a completion gate without becoming auto-completion triggers.
- Task detail explains the blocked action as "Complete checklist items first."
- Home, Task Detail, Watch-relayed completion, and other persistence paths that use task advancement must respect the same rule.
