# 0553: Record Debug Performance Symptoms for Support

## Status

Accepted

## Date

2026-08-12

## Refines

- [0542: Use Validated Release Device Traces for iOS Performance Investigations](0542-use-validated-release-device-traces-for-ios-performance-investigations.md)
- [0516: Make Support Diagnostics Copyable](0516-make-support-diagnostics-copyable.md)

## Context

Reproducing an intermittent lag can be much easier for a developer or tester
than starting and validating an Instruments trace. Existing support diagnostics
describe the build and sync state but cannot show whether a particular run had
high CPU, memory growth, or delayed main-thread responsiveness.

A shipped, unbounded recorder would waste resources and could turn support
artifacts into an accidental source of personal data. Conversely, a lightweight
symptom report cannot name the function responsible for work: that still needs
the validated, symbolicated release-device Time Profiler trace defined by
Decision 0542.

## Decision

Debug builds automatically maintain one overwritten, privacy-safe JSON
performance profile in their app-support container. The profile has bounded
resource samples, main-queue health-check delays, lifecycle events, build and
operating-system metadata, and explicit manual reproduction-end markers. It
does not record task content, account information, identifiers, credentials,
network payloads, screenshots, or screen recordings.

The Debug Support & About diagnostics surface offers `Mark End of
Reproduction` and a native `Share Performance Profile` action. The recorder
flushes at launch, periodically, after significant events, and when the app is
about to terminate, so a profile remains available without an explicit export
step.

The profile is a symptom-and-timeline handoff artifact only. It can guide a
follow-up investigation, but performance conclusions about shipping iOS remain
subject to Decision 0542's Release device baseline and validated Time Profiler
trace requirements.

## Consequences

- A Debug Xcode run leaves a directly shareable file even when the reproduction
  is intermittent or a tester cannot configure Instruments.
- Reports remain bounded to 15 minutes of one-second resource samples, 200
  main-thread stalls, and 80 lifecycle events, so the recorder has predictable
  storage and low background overhead.
- Support can correlate a reported delay with CPU, memory, thermal state, and
  scene transitions without receiving user-owned content.
- Diagnosing the responsible call stack still requires a focused Instruments
  trace from the matching build and interaction path.
