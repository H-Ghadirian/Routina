# 0542: Use Validated Release Device Traces for iOS Performance Investigations

## Status

Accepted

## Date

2026-08-11

## Refines

- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)

## Context

Performance judgments about iOS Home, Search, Timeline, and other unbounded
surfaces must represent the production app on a real device. A recent
investigation initially attached Time Profiler by process name and received a
trace whose metadata declared CPU tables but whose exported call tree had no
samples. The physical device also had a development build installed, making a
name-based attachment ambiguous.

Combining several interactions in one unmarked trace makes it difficult to
separate startup or sync work from the work caused by Search activation or
typing. Keeping profiling artifacts after the investigation also risks stale
results being mistaken for evidence from a later build.

## Decision

Production iOS performance investigations must follow the project runbook:
[iOS Production Device Profiling](../ios-production-device-profiling.md).

The investigation must use `RoutinaiOSProd` in `Release`, install the verified
`ir.hamedgh.Routinam` app on a physical device, and attach Time Profiler to the
numeric PID whose executable path is the production app. Each trace covers one
declared interaction path and has a separate idle baseline.

Before analysis, export `time-profile` and verify that it contains Routinam
samples. A table listed in trace metadata is insufficient. If direct PID
attachment yields no samples, repeat the same scenario with `--all-processes`
and isolate Routinam from that call tree. Conclusions must distinguish inclusive
sample categories from exclusive time and compare the interaction trace with
its baseline.

Every profiling session removes its isolated Derived Data, trace bundles,
exports, and temporary helpers before handoff.

## Consequences

- Production-device results are reproducible and tied to a known build, device,
  interaction, and symbol set.
- Empty or ambiguously attached traces cannot produce misleading diagnoses.
- Search, Home, and Timeline work can be attributed to a specific interaction
  rather than a mixed, unmarked recording window.
- Performance investigations leave no stale local artifacts after reporting.
