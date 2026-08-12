# Debug Performance Profiles

Use this lightweight recorder when someone can reproduce a slowdown in an
Xcode Debug run but cannot capture an Instruments trace. It creates a
privacy-safe symptom report; it does not replace Time Profiler for source-level
root cause analysis.

## Capture a profile

1. Run `RoutinaiOSDev` or `RoutinaMacOSDev` from Xcode in the Debug
   configuration. The recorder starts automatically and creates
   `RoutinaPerformanceProfile.json` immediately.
2. Reproduce one problem at a time. The profile also records privacy-safe,
   fixed interaction categories automatically; keep a short note of what you
   did and the approximate time it happened.
3. Optionally end the reproduction with Settings -> Support & About. Long-press
   the Version row for five seconds to reveal Diagnostics, then choose `Mark
   End of Reproduction`.
4. From the same Debug Diagnostics section, choose `Share Performance Profile`
   and attach the JSON file here with the short reproduction note.

If the app crashes or is force-quit, reopen it once, reveal the same Diagnostics
section, and choose `Share Previous Run Profile`. Share it before launching the
app again, because each launch advances the current run into the single
previous-run slot.

The app continually refreshes a current file in its app-support container and
preserves that file as the previous run before a new launch writes anything.
You do not need to close the app first. An abrupt stop can omit roughly the last
five seconds of resource samples, and this profile does not replace an Apple
crash report for a fatal exception or crash call stack.

## What is in the file

- App version, build, platform, operating system, and record-generation time.
- One-second CPU and resident-memory samples, including thermal and low-power
  state.
- Main-queue responsiveness delays of at least 750 milliseconds.
- App-scene lifecycle events and optional reproduction markers.
- A bounded interaction trail for app navigation, scrolling, search state
  without the query, filter changes without values, task lifecycle categories,
  creation entry points, and manual sync/backup actions. Each stall names its
  recent interaction context.

The file excludes tasks, task names, notes, history, account details,
identifiers, search text, tag/filter values, form content, location,
credentials, network content, screenshots, and screen recordings.

## How to interpret it

The report can show whether a lag coincided with high process CPU, memory
growth, heat/low-power state, an app-scene transition, a user interaction such
as Home scrolling or a filter change, or repeated main-thread stalls. It cannot
identify a Swift function or prove the root cause.

For a shipping iOS performance claim or a source-level diagnosis, follow the
[iOS Production Device Profiling runbook](ios-production-device-profiling.md):
capture one validated Release-device baseline and one matching Time Profiler
trace, then compare their symbolicated app-owned call trees.
