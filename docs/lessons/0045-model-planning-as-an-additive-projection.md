# 0045 — Model planning as an additive projection

Date: 2026-07-26

## Symptom

Planning a task for today or tomorrow removed its row from the regular section
where it belonged. Custom-section and pinned tasks could be excluded from the
planning section, and assigning a plan or custom section erased the other
dimension.

## Root Cause

The Home presentation used one global claimed-task set for both durable
organization and date-based planning. Lifecycle mutations reinforced that
exclusive model by clearing custom assignment when planning and clearing the
plan when assigning a custom section.

## Fix

Today and Tomorrow now derive independently deduplicated planning projections.
The ordinary classification pipeline still claims every task once for Pinned,
custom, daily, Future, away, or archived placement. Planning and custom-section
mutations preserve one another.

## Prevention Rule

When one view dimension is an overlay or projection of another, do not feed it
into the base classifier's exclusivity set. Preserve independent stored
dimensions through mutations in both directions.

## Regression Safeguard

`HomeTaskListFilteringTests` verifies that planned tasks remain in regular,
pinned, custom, and Future placement while also appearing in Today or Tomorrow.
`HomeTaskLifecycleSupportTests.planTaskPreservesCustomSectionAssignmentWhenDateIsSet`
protects coexistence of planning and custom assignment. The additive planning
scenario and [Decision 0440](../decisions/0440-treat-day-planning-sections-as-additive.md)
record the intended exception to Home's one-classification rule.
