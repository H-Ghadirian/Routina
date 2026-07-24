# 0018 — Derive mirrored form labels from one section model

Date: 2026-07-24

## Symptom

The Mac task form sidebar called its core timing section `Behavior`, while the corresponding main-form card called it `Scheduling`.

## Root Cause

The sidebar derived its label from `FormSection`, but the card independently hard-coded a second label for the same section.

## Fix

The Behavior card now derives its title from `FormSection.behavior.title`, matching the sidebar's canonical title.

## Prevention Rule

When one logical form section appears in navigation and content, derive both visible titles from the same section model instead of duplicating display copy.

## Regression Safeguard

`Tests/macOS/FormSectionTests.swift` verifies that the Behavior card title matches the sidebar section title and remains `Behavior`. The matching scenario is recorded in `docs/scenarios/README.md`.
