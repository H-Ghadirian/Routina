# 0619: Pin Mac Quick Add Details Through Transient Reparses

Status: Accepted

Date: 2026-08-20

Refines: [0315 Merge Mac Quick Add Into Toolbar Search](0315-merge-mac-quick-add-into-toolbar-search.md), [0616 Interpret Unqualified Quick Add Dates as Availability](0616-interpret-unqualified-quick-add-dates-as-availability.md), [0617 Generate Editable Quick Add Titles from Pasted Links](0617-generate-editable-quick-add-titles-from-pasted-links.md)

## Context

Mac toolbar Quick Add derived both the contents and existence of its Detected details rectangle from the latest create-eligible parser draft. That draft legitimately becomes unavailable while live search refreshes or while the person is midway through syntax such as a date, time, or tag. The entire rectangle therefore disappeared and reappeared even though the person was still composing the same task, creating visual movement and weakening confidence that its editable title and reminder controls were stable.

## Decision

- Detected details begins only after the current query is confirmed as a no-result create candidate with recognized metadata.
- Once shown, its outer container remains mounted for the active expanded Quick Add composition. The newest parsable draft updates the content inside the existing container even when it temporarily has no recognized metadata.
- If an intermediate non-empty value cannot be parsed, the container shows a noninteractive `Updating details…` state instead of exposing stale controls or disappearing.
- Transient asynchronous search eligibility does not own the container's identity. A confirmed existing task or Timeline-style result dismisses it so the search-or-create guard remains unambiguous.
- Clearing the query, successful creation, Escape, or outside-click collapse ends the visible presentation. Refocusing unchanged text may show its still-valid detected details again.

## Consequences

- Typing no longer makes the Detected details rectangle flicker or repeatedly animate from the toolbar.
- Editable titles, reminder choices, and URL metadata retain the continuity established by Decisions 0616 and 0617 while the rows around them update.
- Routina never presents stale reminder or title controls for an unparsable intermediate query, and existing-result searches still cannot look like create candidates.
