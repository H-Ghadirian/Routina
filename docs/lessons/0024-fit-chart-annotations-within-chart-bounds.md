# 0024 — Fit chart annotations within chart bounds

Date: 2026-07-25

## Symptom

On macOS Stats charts, an average-rule badge such as `Avg 2,6` could render beyond the leading edge of its chart card.

## Root Cause

The horizontal `RuleMark` annotation was anchored at its leading edge without an annotation overflow policy. Swift Charts could therefore place the badge outside the chart when resolving a horizontally scrolled or constrained plot.

## Fix

The average annotations now use horizontal chart-bound fitting while leaving vertical overflow behavior unchanged.

## Prevention Rule

Edge-anchored chart annotations must declare an overflow resolution that fits their horizontal placement to the chart.

## Regression Safeguard

A source-based Stats regression test checks that every shared average-rule chart applies horizontal chart fitting.
