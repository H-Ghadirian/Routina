# Debug Performance Profiles

Use this lightweight recorder when someone can reproduce a slowdown in an
Xcode Debug run but cannot capture an Instruments trace. It creates a
privacy-safe symptom report; it does not replace Time Profiler for source-level
root cause analysis.

## Capture a profile

1. Run `RoutinaiOSDev` or `RoutinaMacOSDev` from Xcode in the Debug
   configuration. The recorder starts automatically and creates
   `RoutinaPerformanceProfile.json` immediately.
2. Reproduce one problem at a time. Keep a short note of what you did and the
   approximate time it happened.
3. Optionally end the reproduction with Settings -> Support & About. Long-press
   the Version row for five seconds to reveal Diagnostics, then choose `Mark
   End of Reproduction`.
4. From the same Debug Diagnostics section, choose `Share Performance Profile`
   and attach the JSON file here with the short reproduction note.

The app continually refreshes a single current file in its app-support
container. You do not need to close the app first; backgrounding or force
quitting after the profile has been flushed will still leave the latest written
file available.

## What is in the file

- App version, build, platform, operating system, and record-generation time.
- One-second CPU and resident-memory samples, including thermal and low-power
  state.
- Main-queue responsiveness delays of at least 750 milliseconds.
- App-scene lifecycle events and optional reproduction markers.

The file excludes tasks, task names, notes, history, account details,
identifiers, credentials, network content, screenshots, and screen recordings.

## How to interpret it

The report can show whether a lag coincided with high process CPU, memory
growth, heat/low-power state, an app-scene transition, or repeated main-thread
stalls. It cannot identify a Swift function or prove the root cause.

For a shipping iOS performance claim or a source-level diagnosis, follow the
[iOS Production Device Profiling runbook](ios-production-device-profiling.md):
capture one validated Release-device baseline and one matching Time Profiler
trace, then compare their symbolicated app-owned call trees.
