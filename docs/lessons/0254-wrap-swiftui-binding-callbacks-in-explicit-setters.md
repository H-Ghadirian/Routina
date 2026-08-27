# 0254 — Wrap SwiftUI binding callbacks in explicit setters

Date: 2026-08-27

## Symptom

The Mac app target aborted during compilation with signal 6 after inline Stats
pickers were introduced. Swift IR generation reported `SmallVector unable to
grow` while emitting `HomeMacStatsSidebarSections.swift`, even though package
tests compiled and passed.

## Root Cause

The new picker bindings passed stored callback functions directly as
`Binding` setters. Under Swift 6, adapting those non-Sendable function values to
SwiftUI's isolated Sendable setter representation generated conversion thunks
that triggered a compiler IR-generation defect in the large Mac app batch.

## Fix

Each binding now uses an explicit setter closure that calls the stored callback
or range-selection method. This removes the problematic function-value
conversion while preserving the same synchronous selection behavior.

## Prevention Rule

When a SwiftUI `Binding` adapts a stored callback or instance method, wrap the
call in an explicit setter closure instead of passing the function value
directly. Treat new Sendable-conversion warnings on binding setters as build
risks, not harmless presentation warnings.

## Regression Safeguard

The required `RoutinaMacOSDev` build-and-launch completion gate compiles these
bindings in the full SwiftUI app target, where the compiler defect occurred;
package-only coverage is not sufficient for this class of failure.
