# 0234 — Scope automatic organization to its surface

Date: 2026-08-23

## Symptom

Existing hidden tasks whose tags matched a newly configured Backlog section
remained in `Hidden by flag`, even though other matching tasks entered the
section.

## Root Cause

The Backlog snapshot treated any non-nil custom-section ID as an explicit
Backlog assignment blocker. That field can instead identify a Main task list
path, so a rule in one section catalog was incorrectly blocked by organization
owned by the other surface.

## Fix

Backlog now treats only explicit Backlog section IDs as stronger than Backlog
automatic tag rules. A matching hidden task may retain its stored Main task
list path while being classified into a Backlog super section for presentation.
Removing the hiding Flag reveals the retained Main task list path again.

## Prevention Rule

When one stored identity can refer to entries in separate catalogs, evaluate
automatic-rule precedence against the active catalog rather than treating every
non-nil identity as an assignment in that surface.

## Regression Safeguard

The Mac Backlog regression scenario now distinguishes Main task list and
Backlog precedence. `BacklogTaskListPresentationTests` covers a hidden task with
a retained Main task list assignment before and after a matching Backlog rule
is added, then verifies that removing the hiding Flag preserves its Main path.

This refines the initial presentation-routing lesson in
[0227](0227-route-backlog-tag-rules-through-the-presentation-model.md).
