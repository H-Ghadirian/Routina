# 0502: Keep Mac Task Forms and Search Input Frame-Safe

## Status

Accepted

## Date

2026-08-07

## Refines

- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0419: Use Lightweight Surfaces Inside Unbounded Scroll Rows](0419-use-lightweight-surfaces-inside-unbounded-scroll-rows.md)
- [0471: Use Lightweight Segmented Surfaces in Scrolling Task Forms](0471-use-lightweight-segmented-surfaces-in-scrolling-task-forms.md)

## Context

Mac Add Task, Edit Task, and Task Detail's inline `Add more details` path can reveal enough cards and segmented controls to make scrolling visibly lag. The form eagerly constructed every revealed card, including off-screen cards, and each one sampled a Liquid Glass backdrop.

Toolbar search also delivered every keystroke directly to task-list and timeline presentation. A search update could rebuild a large presentation while the field was receiving input. The AppKit bridge then scheduled three first-responder repairs after every character, making the field fall behind when those updates were expensive.

## Decision

Mac task forms use a lazy vertical stack for scrolling sections. Their cards, segmented controls, and noninteractive schedule-preview badges use lightweight tinted fills while preserving their existing layout, borders, accessibility, and full control hit areas. This includes the inline Add More form cards in Task Detail.

Toolbar search keeps its raw editor text immediate, but applies that text to expensive task and timeline presentations after a 120-millisecond idle debounce. Clearing search remains immediate. The create hint waits for the applied query, and the actual Return action continues to check the current raw query synchronously before creating a task.

AppKit focus repair remains available for explicit focus and submission transitions, but never runs for an ordinary text-change notification.

## Consequences

- Scrolling a long Mac task form only creates the nearby cards and avoids multiplying backdrop-sampling layers.
- Search characters remain responsive even with a large task or timeline history; result updates may settle shortly after a burst of typing.
- Search still prevents duplicate Quick Add creation when the current query matches an existing task or timeline entry.
- Future Mac task-form surfaces and toolbar input paths must treat per-frame compositing and per-keystroke whole-presentation work as performance-sensitive.
