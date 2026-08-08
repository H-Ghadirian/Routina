# 0106 — Let assigned Flag chips use available width

Date: 2026-08-08

## Symptom

An assigned Auto Assumed Done Flag was truncated in iOS Task Details despite
substantial unused space in the Flags section.

## Root Cause

The Flags section used an 88-point adaptive grid for every state. With one
Flag, SwiftUI still created narrow adaptive columns, so the chip received only
one 88-point cell instead of the available row width.

## Fix

One assigned Flag now renders in a leading HStack and receives the section's
available width. Multiple Flags use wider 160-point adaptive cells.

## Prevention Rule

Do not put an intrinsically sized chip in a narrow adaptive grid when a
single-item state has unused horizontal space. Give a single chip its available
row width, and size multi-item grid cells for ordinary labels.

## Regression Safeguard

Tests/Shared/TaskDetailFlagPresentationTests.swift checks the single-Flag
path and the wider multi-Flag grid. The Task Detail Flags scenario records the
expected label behavior.
