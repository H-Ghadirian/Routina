# 0077 — Avoid Liquid Glass multiplication in scrolling forms

Date: 2026-08-04

## Symptom

The iOS Add Task screen scrolled smoothly for a one-time task but developed a
visible hiccup after the user selected the Repeating task type.

## Root Cause

Repeating progressively revealed several segmented controls at once. Every
control owned a Liquid Glass container plus a selected-segment glass effect,
and the Due Style preview added more glass badges. Moving all of those backdrop
surfaces with the native scrolling `Form` increased compositor work. The form
also rebuilt its section catalog multiple times within one body evaluation.

## Fix

The iOS task form now supplies a lightweight scrolling surface style to every
descendant segmented control. The style preserves selection tint, borders,
accessibility, and hit targets using simple shapes without glass backdrops.
Schedule-preview badges use lightweight pill fills, and the form shares one
visible/hidden section presentation per render.

## Prevention Rule

Do not multiply independently composited Liquid Glass surfaces inside a
scrolling form when progressive disclosure can reveal several controls
together. Provide a container-level lightweight style so current and future
controls inherit the performance-safe rendering path automatically, and derive
shared section catalogs once per body evaluation.

## Regression Safeguard

`IOSScrollingPerformanceRegressionTests.taskFormsAvoidLiquidGlassAndDuplicateSectionDerivationWhileScrolling`
requires the iOS task-form environment override, the lightweight segmented and
badge paths, and the single shared section presentation. Decision
[0471](../decisions/0471-use-lightweight-segmented-surfaces-in-scrolling-task-forms.md)
records the durable boundary.
