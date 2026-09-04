# 0290 — Aggregate duration before converting units

Date: 2026-09-03

## Symptom

Adventure undercounted planned hours when several sub-hour Planner blocks
combined into a full hour. A 30-minute block and a 90-minute block earned one
planned hour instead of two.

## Root Cause

Each block's minutes were divided by 60 before the results were summed, so the
integer remainder from every block was discarded independently.

## Fix

Nonnegative Planner minutes are summed first and the aggregate is converted to
whole hours once.

## Prevention Rule

When a reward or metric is based on an aggregate duration, sum in the smallest
stored unit before applying integer conversion or rounding.

## Regression Safeguard

`HomeAdventureProgressionTests.build_awardsCoinsForMacActivitySources` combines
90- and 30-minute blocks and expects two planned hours.
