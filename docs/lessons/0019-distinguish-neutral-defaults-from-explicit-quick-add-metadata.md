# 0019 — Distinguish neutral defaults from explicit Quick Add metadata

Date: 2026-07-25

## Symptom

A one-time task created from Mac Home search without priority syntax showed Priority in Task Details as `Medium / Medium`.

## Root Cause

The Quick Add parser used medium importance and urgency as neutral defaults, but its save request always converted that matrix position into an explicit medium priority. The persistence layer therefore could not distinguish omitted priority syntax from a user-entered `!medium`.

## Fix

Quick Add drafts now retain whether priority syntax was explicitly parsed. Syntax-free drafts save `.none` priority while preserving neutral matrix defaults; explicit `!low`, `!medium`, `!high`, and `!urgent` values continue to save their derived priorities and appear in previews and forms.

## Prevention Rule

When a parser uses a valid domain value as its neutral default, carry separate presence information through persistence instead of inferring user intent from the value alone.

## Regression Safeguard

`RoutinaQuickAddParserTests.createTaskWithoutPrioritySyntaxKeepsPriorityUnset` verifies the search-bar creation shape and confirms that Task Details keeps Priority hidden.
