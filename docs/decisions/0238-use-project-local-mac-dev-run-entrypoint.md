# 0238: Use Project-Local Mac Dev Run Entrypoint

## Status

Accepted

## Date

2026-06-13

## Context

The macOS development app can be built from Xcode, but launching it manually requires knowing the current DerivedData path. That makes the build-and-run loop fragile for agents and for the Codex app Run action, especially when DerivedData is cleaned or changes between machines.

## Decision

Routina uses `script/build_and_run.sh` as the project-local macOS dev build-and-run entrypoint. The script builds `RoutinaMacOSDev` with `xcodebuild` into a deterministic project-local derived data path, stops any existing dev app process, and launches the freshly built app. `.codex/environments/environment.toml` wires the Codex Run action to that script.

## Consequences

- The default macOS dev run path no longer depends on manually locating global Xcode DerivedData.
- Agents and the Codex app can use one command for the normal kill, build, and launch loop.
- Debugging and diagnostics can use the script flags for logs, telemetry, debugger launch, or process verification.
