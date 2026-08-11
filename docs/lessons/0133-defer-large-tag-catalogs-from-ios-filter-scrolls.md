# 0133 — Defer large tag catalogs from iOS filter scrolls

Date: 2026-08-11

## Symptom

The iOS Home Filters sheet scrolled slowly and hitched when the saved tag
catalog was large.

## Root Cause

The sheet built tag summaries from the entire Home display set and rendered
every tag as wrapping chips for both include and exclude rules. This made
opening and scrolling the general filter surface scale with catalog size.

## Fix

Home Filters now keeps a lightweight Tags entry and opens the full catalog only
in a searchable, native List-based Tag picker after the person chooses it.

## Prevention Rule

Do not put an unbounded catalog or its complete-data derivation inside an iOS
filter sheet's normal scrolling path. Use an explicit, on-demand picker with a
cached displayed row list instead.

## Regression Safeguard

`IOSScrollingPerformanceRegressionTests.homeDefersItsTagCatalogUntilTheTagPickerOpens`
asserts that Home Filters does not pass eager tag data into its main sheet and
that the picker owns its refreshed displayed catalog. The Home Tag Filtering
scenario records the intended interaction.
