# 0227 — Route Backlog Tag Rules Through the Presentation Model

Date: 2026-08-23

## Symptom

Creating a tagged Backlog super section did not show matching unassigned
tasks in that section; they remained in `Hidden by flag`.

## Root Cause

The Backlog presentation grouped tasks only by their stored
`customTaskSectionID`. Main task-list filtering evaluated super-section tag
rules, but the separate Backlog snapshot did not perform an equivalent
automatic classification step.

## Fix

The Backlog snapshot now claims active, unfinished, uncanceled, hidden-by-Flag
tasks with no explicit section in the first matching top-level Backlog super
section. Explicit assignments remain authoritative, and ordinary Radar tasks
are not treated as Backlog candidates.

## Prevention Rule

When a workspace has its own cached presentation for a shared organization
model, every supported automatic-routing rule must be represented in that
workspace's snapshot builder with the same precedence rules as the primary
surface.

## Regression Safeguard

`BacklogTaskListPresentationTests` verifies matching hidden tasks route into a
tagged Backlog super section, explicit assignments are preserved, unmatched
tasks remain in `Hidden by flag`, and ordinary Radar tasks are not pulled into
Backlog by a matching tag rule.
