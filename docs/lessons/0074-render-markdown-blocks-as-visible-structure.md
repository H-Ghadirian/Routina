# 0074 — Render Markdown blocks as visible structure

Date: 2026-08-02

## Symptom

The Description editor offered bullet-list and checklist controls, but Task Details removed bullet markers and displayed checklist source such as `[ ]` instead of a checkbox. Heading and quote source had the same underlying risk of losing its block presentation.

## Root Cause

The shared formatted-text view parsed each line with Foundation's full Markdown parser and passed the result to one SwiftUI `Text`. Foundation recorded headings, lists, and quotes as block presentation intents, but `Text` did not draw the corresponding markers or block styling. The parser therefore removed source markers without replacing them with visible structure.

## Fix

The shared renderer now recognizes the Markdown block forms that Routina's toolbar inserts. It presents headings with heading typography, bullets with visible markers, checked and unchecked checklist items with matching symbols, and quotes with a distinct quote treatment. Inline Markdown remains parsed inside each block, while saved plain-text Markdown is unchanged.

## Prevention Rule

Every formatting control exposed by an editor must have a verified semantic presentation on read surfaces. Do not assume that Markdown parser metadata is visibly rendered by a generic text view.

## Regression Safeguard

`TaskDetailCommentsTests.formattedTextPresentsMarkdownBlockControlsSemantically` verifies the shared renderer's heading, bullet, checklist, quote, and inline formatting output. A companion test protects ordinary hyphens and bracket text from being misclassified as blocks.
