# 0450: Use Progressive Custom Section Management

Date: 2026-07-28

Status: Accepted

Refines: [0188 Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md), [0264 Match Button Hit Areas to Visual Surfaces](0264-match-button-hit-areas-to-visual-surfaces.md), [0411 Manage Custom Task Sections in Settings](0411-manage-custom-task-sections-in-settings.md), [0419 Nest Custom Subsections Under Super Sections](0419-nest-custom-subsections-under-super-sections.md), [0449 Keep Custom Section Rules Tag-Based](0449-keep-custom-section-rules-tag-based.md)

Refined by: [0460 Match Custom Section Tags by Any or All](0460-match-custom-section-tags-by-any-or-all.md)

## Context

Mac Settings rendered every custom section as a permanently expanded form.
Large catalogs repeated name, Save, Delete, color, tag, and subsection controls
until the page became difficult to scan. Destructive buttons were as prominent
as ordinary edits, complete tag values were repeated below their field, and an
unrelated persistence update could replace an unfinished name or tag draft.

The section catalog also has meaningful manual order, but Settings did not
offer a direct way to change it.

## Decision

Settings -> Sections presents custom super sections as compact summary cards.
The first card starts expanded, only one card is expanded at a time, and
clicking anywhere across the card header toggles its editor. Collapsed headers
show the section color, name, automatic-tag summary, and subsection count.
Creating a section expands the new card.

The expanded editor groups name and color, automatic tags, and subsections.
Save and revert controls appear only while a field has an unfinished change.
Tag values are not repeated as passive copy after the editable field.
Destructive actions and sibling Move Up / Move Down actions live in native More
menus for super sections and subsections. Deletion continues to require a
confirmation that describes descendant and task-placement effects.

Draft synchronization distinguishes the last persisted value from the local
draft. Persistence updates adopt external changes only when that field is still
unchanged locally, so changing a color, order, or neighboring section cannot
erase unfinished name or tag input.

## Consequences

- Large section catalogs remain scannable without removing editing capability.
- Destructive actions remain discoverable without dominating every row.
- Section and subsection order can be managed from the same Settings surface.
- Unfinished text survives unrelated catalog writes while untouched fields
  still adopt external updates.
- The custom disclosure header must retain a full-width hit shape.
