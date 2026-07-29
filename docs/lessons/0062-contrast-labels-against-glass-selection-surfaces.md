# 0062 — Contrast labels against glass selection surfaces

Date: 2026-07-29

## Symptom

In the iOS Home Filters sheet under Task Type, the selected `All` label and
symbol disappeared against the bright selected glass segment in dark mode.

## Root Cause

The shared glass segmented control used the environment's semantic `.primary`
color for selected labels. In dark appearance that resolves to a light
foreground, but the selected Liquid Glass lens itself is also bright, leaving
too little contrast.

## Fix

The shared segmented-control default now uses an explicit dark foreground for
selected labels while retaining the semantic secondary foreground for
unselected labels.

## Prevention Rule

Choose foreground colors against the control's rendered surface, not only
against the surrounding appearance. A bright custom selection surface needs a
contrasting foreground even when the surrounding screen is dark.

## Regression Safeguard

`RoutinaLiquidGlassContrastTests` verifies that both shared segmented-control
initializers retain the contrasting selected-label default. The matching
Given/When/Then behavior is recorded in `docs/scenarios/README.md`.
