# 0293 — Preserve closure-backed sections during extraction

Date: 2026-09-03

## Symptom

The Mac task filter detail stopped showing its Flag section after shared view
code was extracted, even though the caller still supplied Flag content and its
visibility condition.

## Root Cause

The extracted container retained the `showsFlagSection` input and
`flagSectionContent` closure but omitted the conditional invocation from its
Filter tab composition.

## Fix

The Filter tab renders `flagSectionContent()` whenever `showsFlagSection` is
true.

## Prevention Rule

When extracting a closure-backed view container, inventory every input at the
call site and verify that each conditional content closure remains invoked in
the new composition.

## Regression Safeguard

`HomeMacAllFiltersSourceTests` and
`PerformanceRegressionTests.testMacHomeFiltersUseRightSideCompanionPane`
require both the Flag visibility branch and closure invocation while preventing
the container from constructing a duplicate Flag implementation.
