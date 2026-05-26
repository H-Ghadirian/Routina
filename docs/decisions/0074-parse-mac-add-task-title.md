# 0074: Parse Mac Add Task Title

## Status

Accepted

## Date

2026-05-26

Updates [0058](0058-use-progressive-task-forms.md) and complements [0072](0072-unify-ios-task-add-and-quick-add.md).

## Context

iOS task creation now starts with a smart quick-add surface that parses natural-language task text. macOS still benefits from the full Add Task form as the default creation surface because desktop users can comfortably scan and edit richer fields.

Keeping a separate Mac quick-add parser outside the Add Task form makes the title field feel less capable than the iOS entry point and can force users to choose the right creation surface before typing.

## Decision

macOS Add Task keeps the full progressive form, but the task title field accepts quick-add syntax such as recurrence, dates, time, tags, places, priority, and duration.

When the title contains detected metadata, the Mac identity section shows a readable preview and an Apply action. Applying rewrites the title to the cleaned task name and populates the matching form fields.

Saving also applies any uncommitted parsed title metadata before creating the task so users do not have to press Apply for the parser to work.

## Consequences

- Mac and iOS share the same quick-add language while preserving platform-specific creation surfaces.
- The title field remains the first focus target on Mac, but it can now capture richer intent.
- Form fields remain editable after parsing, so users can correct parser output before saving.
