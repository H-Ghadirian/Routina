# 0017 — Bound growing form suggestion lists

Date: 2026-07-24

## Symptom

The Mac Add Task and Edit Task Tags section grew to several lines because it rendered every saved tag.

## Root Cause

The tag chip view filtered selected and related tags but placed no display limit on the remaining catalog. Its default layout therefore scaled with all historical user data.

## Fix

The collapsed form now shows selected tags, related suggestions, and only the six highest-use remaining tags. A full-surface disclosure button expands or collapses the complete list.

## Prevention Rule

Suggestion collections backed by user-created catalogs must have a bounded default presentation and an explicit route to the full collection.

## Regression Safeguard

`TaskFormMacTagSuggestionPresentationTests` verifies both the six-tag collapsed limit and complete expanded result.
