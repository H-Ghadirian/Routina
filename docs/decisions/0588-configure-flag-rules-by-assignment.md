# 0588: Configure Flag Rules by Assignment

## Status

Accepted

## Date

2026-08-16

## Refines

- [0497: Use Flags for Task Behavior Rules](0497-use-flags-for-task-behavior-rules.md)
- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)

## Context

Settings repeated every available behavior rule under every defined Flag. Most
Flags use only one or two rules, so inactive switches dominated the page and
made the assigned behavior harder to scan. The presentation would also grow
linearly for every new rule kind even when a person had not chosen that rule.

## Decision

iOS and macOS Settings show only the rules currently assigned to each Flag.
Each Flag provides an `Add Rule` menu containing only its remaining available
rule kinds, and each assigned rule has a direct removal control. A Flag with no
rules says so without rendering the full rule catalog.

Rule descriptions stay beside assigned rules. The legacy auto-assume migration
action appears only with an assigned `Enable auto-assume done` rule. Adding and
removing rules continues to use the existing synchronized Flag-rule storage and
behavior reconciliation; this is a presentation change, not a data migration.

## Consequences

- A person can scan the behavior actually attached to a Flag without reading
  inactive options.
- Adding a rule is an explicit selection from the rule catalog, while removal
  remains available beside the assigned rule.
- Future rule kinds expand the add menu without adding repeated controls to
  every Flag.
