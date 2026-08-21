# 0629: Consolidate Task Detail Rich Content

## Status

Accepted

## Date

2026-08-21

## Refines

- [0124: Support Multiple Task Links](0124-support-multiple-task-links.md)
- [0211: Support Titled Task Links](0211-support-titled-task-links.md)
- [0469: Store Task Descriptions Separately From Notes](0469-store-task-descriptions-separately-from-notes.md)
- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0627: Group Mac Task Detail Tags and Flags](0627-group-mac-task-detail-tags-and-flags.md)
- [0628: Adapt Mac Task Detail Labels to Available Width](0628-adapt-mac-task-detail-labels-to-available-width.md)

## Context

Mac Task Details showed attached links in a compact header box titled `DETAILS`
while images, files, descriptions, voice notes, and notes appeared later inside a
second card titled `Details`. The two containers held different data, but their
identical generic labels made them look duplicated and implied that an attached
image belonged in the link-only header box.

Moving a full image into the header would make the primary identity, completion,
priority, calendar, and label summary unstable and potentially very tall. The
problem was the content grouping and naming rather than the image's scrolling
position.

## Decision

Task Details present stable task-authored reference content in one shared
scrolling card on iOS and macOS. The card has no generic `Details` heading.
Instead, each populated content type identifies itself with a semantic heading
in this order: Description, Links, Image, File or Files, Voice Note, and Notes.

Mac removes the link-only `DETAILS` box from the supplementary header and passes
its resolved titled links into the shared content card. The Mac header remains a
compact overview for calendar context, Tags and Flags, Points, and Goals. The
full image remains in scrolling content and opens through its existing full
surface action; no header thumbnail or cover-image meaning is introduced.

Existing Notes and Voice Note feature gates, link destinations and copy actions,
file actions, image size limit, and content persistence remain unchanged. The
content card remains absent when none of its supported content is populated.

## Consequences

- A task has one understandable rich-content area instead of two differently
  scoped sections with the same name.
- Links and images appear together as task-authored reference material without
  letting large media displace the task's primary overview.
- A task with only an image says `IMAGE`; mixed content names each present type
  without an extra generic heading.
- iOS and macOS use the same semantic content ordering while retaining their
  native navigation and action differences.
