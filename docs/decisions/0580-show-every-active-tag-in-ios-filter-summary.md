# 0580: Show Every Active Tag in iOS Filter Summary

## Status

Accepted

## Date

2026-08-16

## Revises

[0533: Keep Active iOS Filter Tag Rules Visible](0533-keep-active-ios-filter-tag-rules-visible.md)

## Refines

[0579: Align iOS Filter Tag Picker With Task Tag Picker](0579-align-ios-filter-tag-picker-with-task-tag-picker.md)

## Context

The iOS Filter tags picker made every active rule visible, but returning to the
parent Filters sheet still reduced each Show or Hide rule to its first tag and
a remainder count. At narrow widths, the shared single-line value also
truncated that partial summary. A person therefore could not confirm all of
their selected tags without reopening the picker.

Other filter rows generally summarize one bounded choice and benefit from a
compact single line. Tag filters are different because the selected names are
the meaning of the rule and can contain multiple independently chosen values.

## Decision

The iOS Filter tags entry lists every active tag name. Hidden tags appear first,
followed by Included tags; names within each rule are sorted alphabetically.
The value wraps and the tag row grows vertically as needed, without truncation
or a `+n` replacement.

This multiline behavior belongs only to the Filter tags entry. The shared
filter-row component retains its single-line default for every other filter.
The summary derives only from the already selected tag sets and does not build
or scan the full tag catalog.

## Consequences

- A person can verify every active tag filter from the parent Filters sheet.
- Selecting many tags can make this one row taller, which is intentional and
  remains scrollable with the rest of the sheet.
- Other filter rows keep their existing compact height and truncation behavior.
- The deferred full-catalog performance boundary remains unchanged.
