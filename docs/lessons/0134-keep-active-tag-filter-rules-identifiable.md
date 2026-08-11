# 0134 — Keep active tag filter rules identifiable

Date: 2026-08-11

## Symptom

Home Filters showed a count such as `1 hidden` without naming the tag. Opening
the Tag picker on Show then hid that active exclusion behind a separate tab.

## Root Cause

The catalog-deferred filter design treated an active selection as a count in
the parent and made the picker start from a fixed Show rule. It did not reserve
a visible place for selections that belonged to the other rule.

## Fix

The compact entry now names active tags, prioritizing hidden tags. The picker
starts on Hide when appropriate and pins all selected Show and Hide tags above
its catalog with direct removal actions.

## Prevention Rule

When a chooser separates available items into modes or tabs, always surface
the current selections independently of the active mode. Counts alone are not
an adequate summary for a behavior-changing filter.

## Regression Safeguard

`IOSScrollingPerformanceRegressionTests.homeDefersItsTagCatalogUntilTheTagPickerOpens`
asserts that the picker owns a visible selected-tag presentation and prefers
the Hide rule when exclusions are active. The Home Tag Filtering scenario
covers the interaction.
