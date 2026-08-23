# 0647: Scope Automatic Section Rules to Their Surface

## Status

Accepted

## Date

2026-08-23

## Revises

- [0640: Route Unassigned Backlog Candidates by Tags](0640-route-unassigned-backlog-candidates-by-tags.md)

## Refines

- [0635: Separate Mac Settings Section Surfaces](0635-separate-mac-settings-section-surfaces.md)
- [0460: Match Custom Section Tags by Any or All](0460-match-custom-section-tags-by-any-or-all.md)

## Context

Main task list and Backlog super sections are separate catalogs with separate
automatic tag rules. Backlog initially treated any stored section assignment
as stronger than its automatic rules, including an assignment belonging to the
Main task list catalog. As a result, an active task hidden by a Flag could match
a Backlog rule exactly yet remain in `Hidden by flag` solely because it retained
the Main task list path it should return to when the Flag is removed.

The person confirmed that the two surfaces should own separate rules rather
than compete through one cross-surface precedence check.

## Decision

Automatic section-rule eligibility is scoped to the section's surface.

For the Backlog presentation, an explicit Backlog super-section or subsection
assignment remains stronger than every Backlog automatic rule. A Main task list
assignment does not block a matching Backlog rule while the task is an active,
unfinished, uncanceled hidden-by-Flag Backlog candidate. The Backlog rule is
presentation-only and does not replace the stored Main task list assignment.

When the hiding Flag is removed, the task leaves Backlog and its retained Main
task list assignment becomes visible again. A task without the hiding behavior
never enters Backlog solely because its tags match. The first matching Backlog
super section remains the automatic destination, and Backlog subsections remain
manual.

## Consequences

- Main task list and Backlog tag rules can classify the same task in their own
  applicable surface without overwriting each other's organization.
- Creating or editing a Backlog tag rule reclassifies existing matching hidden
  tasks even when they retain Main task list paths.
- Explicit Backlog assignments remain stable and authoritative inside Backlog.
- Removing the hiding Flag restores the task's previous Main task list path.
