# 0283 Preserve Mac Future Inner Sections

Status: Accepted

Date: 2026-06-26

Refines: [0281 Collapse Mac Future Tasks](0281-collapse-mac-future-tasks.md)

Refined by: [0285 Clarify Mac Sidebar Section Surfaces](0285-clarify-mac-sidebar-section-surfaces.md)

## Context

Decision 0281 made future work less visually dominant by wrapping normal active Mac sidebar tasks in a collapsed `Future` section. The first implementation preserved grouping labels inside `Future`, but tag groups no longer behaved like their previous top-level sections.

The `Future` wrapper should not erase the user's chosen grouping mode. Tag sections are meaningful work buckets with color and independent collapse state, and users expect them to stay manageable when moved under `Future`.

## Decision

`Future` remains the top-level collapsed-by-default section for normal active Mac sidebar tasks outside `Plan to do today`.

Inside `Future`, tag and untagged groups render as nested section surfaces with their existing color treatment, count, full-header hit target, and independent collapsed/expanded state. Status, deadline, and ungrouped modes remain simple inner groups without adding redundant nested section chrome.

`Plan to do today` and `Future` render their top-level headers as standalone header surfaces. When expanded, their child content is not inset by the old whole-section card padding; nested tag sections own their own internal padding.

## Consequences

Future work stays visually grouped under one disclosure while tag users keep the old color and collapse affordances inside that wrapper.

Collapsed nested tag state is stored separately from the parent `Future` disclosure so collapsing `Future` does not overwrite individual tag choices.
