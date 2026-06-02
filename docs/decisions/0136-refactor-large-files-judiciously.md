# 0136: Refactor Large Files Judiciously

## Status

Accepted

## Date

2026-06-02

## Context

Routina has grown enough that some implementation files can accumulate unrelated responsibilities. Large files make future changes harder to review, increase merge risk, and can hide useful ownership boundaries. At the same time, splitting code only because a file crossed a number can make navigation worse and create shallow wrapper types that do not clarify the system.

## Decision

When meaningful work touches a source file that is over roughly 500 lines of code, treat that as a prompt to consider a refactor as part of the change. Prefer extracting meaningful concepts into smaller classes, structs, files, functions, view components, reducers, services, or helper types when doing so improves cohesion, readability, testability, ownership boundaries, or reviewability.

The refactor should be smart and behavior-preserving. It should follow existing module and platform patterns, keep related state and behavior together, avoid broad unrelated rewrites, and include verification proportional to the risk of the move.

Do not refactor only for the sake of reducing a line count. It is acceptable to leave a large file intact when the current shape is clearer than the split, when the file is generated or declarative glue, when splitting would create weak abstractions, or when the active change is too urgent or risky to combine with a structural move.

## Consequences

- Future changes should notice large touched files and opportunistically improve their structure when the benefit is real.
- Reviewers can ask for a focused refactor when a large-file change makes responsibilities harder to understand.
- The 500-line threshold is guidance, not a hard build rule or mandate for mechanical file splitting.
