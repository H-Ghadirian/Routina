# 0617: Generate Editable Quick Add Titles from Pasted Links

Status: Accepted

Date: 2026-08-20

Refines: [0074 Parse Mac Add Task Title](0074-parse-mac-add-task-title.md), [0211 Support Titled Task Links](0211-support-titled-task-links.md), [0315 Merge Mac Quick Add Into Toolbar Search](0315-merge-mac-quick-add-into-toolbar-search.md), [0616 Interpret Unqualified Quick Add Dates as Availability](0616-interpret-unqualified-quick-add-dates-as-availability.md)

## Context

Pasting a web link by itself into Quick Add left the URL as task-name text and did not populate the task's link metadata. A person saving a video, article, issue, or other page therefore had to open the full form and repeat information that the URL and page metadata could already provide.

Routina already stores ordered links with optional display titles. Quick Add must remain immediately responsive and useful when the network, webpage, or metadata provider is unavailable, and a fetched title must never replace a title the person has edited.

## Decision

- The shared Smart Add and Quick Add parser extracts HTTP/HTTPS URLs before tags, places, dates, times, and other syntax so characters inside a URL are not interpreted as task metadata.
- If the input contains only a URL, parsing immediately proposes a deterministic fallback task title. YouTube links use `Watch YouTube video`, GitHub links use `Review GitHub link`, and other links use their normalized host. Text typed beside a URL remains the task title and is never replaced by fetched metadata.
- Mac toolbar Quick Add asynchronously requests metadata for the primary public URL without blocking typing or Return-to-create. Local, private-network, credential-bearing, and non-HTTP URLs are not fetched.
- When metadata supplies a title for URL-only input, the preview proposes a task-friendly title and exposes it in an editable task-title field. YouTube titles use a `Watch:` prefix and GitHub titles use `Review:`. The resolved page title is also preserved as the titled link metadata.
- The first user edit owns the proposed title. A later metadata result cannot overwrite it. Pressing Return creates the task with the title currently shown; creation does not wait for metadata and Routina never silently renames the task after saving.
- Metadata and deterministic URL rules are the primary title sources. AI is not required for capture, avoiding latency, availability, privacy, and hallucination dependencies in the immediate path.

## Consequences

- A pasted YouTube URL immediately becomes a linked task and can improve from `Watch YouTube video` to a meaningful video-specific title when metadata arrives.
- Offline or failed metadata lookup still leaves a valid, editable task and link.
- Pasting a public URL can contact its website to obtain metadata; Routina avoids automatic requests for obviously local or credential-bearing destinations.
- Shared non-Mac Quick Add paths persist detected links and deterministic titles, while the interactive asynchronous metadata preview is currently Mac-specific.
