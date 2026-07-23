# Bug-Fix Lessons

This directory contains durable lessons learned from Routina bug fixes. Each fixed bug gets its own note so the cause and prevention guidance remain easy to find during later development.

## How to Use This Log

- After every bug fix, add one numbered Markdown note and add it to the index below.
- Name notes `NNNN-short-description.md`, using the next available four-digit number.
- Focus on reusable engineering knowledge rather than a chronological work summary.
- Link relevant decision records, regression scenarios, tests, and source files when useful.
- If several symptoms share one root cause and are fixed together, one lesson note is sufficient.
- If a later fix changes the understanding of an older lesson, add a new note and cross-link both rather than rewriting history.

## Note Template

```markdown
# NNNN — Short lesson title

Date: YYYY-MM-DD

## Symptom

What users or developers observed.

## Root Cause

Why the defect occurred.

## Fix

What changed to correct it.

## Prevention Rule

The concrete rule future development should follow.

## Regression Safeguard

Tests, scenarios, assertions, tooling, or review checks that protect against recurrence.
```

## Index

No lessons recorded yet.
