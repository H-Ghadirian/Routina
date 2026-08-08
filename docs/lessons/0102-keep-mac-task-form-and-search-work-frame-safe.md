# 0102 — Keep Mac task-form and search work frame-safe

Date: 2026-08-07

## Symptom

Mac Add Task, Edit Task, and inline Add More scrolling could hitch after several optional sections were visible. Typing into toolbar search could visibly fall behind the keyboard.

## Root Cause

The form eagerly built all revealed cards and each card owned a Liquid Glass backdrop. Toolbar search recomputed large task and timeline presentations for every character, then scheduled multiple AppKit first-responder repairs for each text-change notification.

## Fix

The Mac task form now lazily builds its scrolling cards and uses lightweight form surfaces. Search keeps raw native input immediate, debounces expensive presentation updates for 120 milliseconds, and no longer repairs responder focus after ordinary typing.

## Prevention Rule

Do not eagerly materialize off-screen task-form content or multiply backdrop-sampling surfaces in a scrolling form. Keep continuously edited native text controls free of per-character responder mutations and batch expensive derived-search presentation work behind a short idle boundary.

## Regression Safeguard

`Tests/macOS/PerformanceRegressionTests.swift` checks the lazy task-form path, lightweight visual surfaces, debounced applied search state, and absence of text-change focus repair. The interaction is recorded in `docs/scenarios/README.md` and Decision [0502](../decisions/0502-keep-mac-task-forms-and-search-input-frame-safe.md).
