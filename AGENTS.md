# Routina Agent Notes

## User Permission Preferences

- Always ask the user before taking screenshots, screen captures, or recording the screen. Never capture the screen without explicit permission in the current conversation.
- Project-local generated build cleanup is pre-approved for verification artifacts, including `DerivedData` and other macOS build files generated under the project-local `.codex/` folder. Treat cleanup commands like `rm -rf .codex/DerivedDataTaskDetailTodayIOS`, `rm -rf .codex/DerivedDataTaskDetailTodayMac`, or any other `rm -rf .codex/DerivedData*` command as already approved by the user when they remove generated build output. Do not ask the user again before running those project-local cleanup commands; run them when useful and tell the user afterward exactly what cleanup was performed.
- After every profiling session, remove all project-local profiling artifacts before finishing, including CPU samples, traces, temporary profiling helpers and binaries, profiling logs, and profiling-specific `.codex/DerivedData*` directories. Verify that none remain and report exactly what was removed.

## Project Decision Log

- Before making meaningful project changes, read `docs/decisions/README.md` and any relevant decision records.
- Before implementing a meaningful request, check whether it contradicts existing current behavior or decision records. If it does, pause before code changes, explain the conflict briefly with the relevant decision/current-behavior reference, and ask for explicit user permission before proceeding.
- After making a change that introduces or revises long-term decisions, add a new decision record or supersede an existing one.
- Decision records should capture why a choice was made, not every small implementation detail. Use them for architecture, conventions, data model, dependencies, product behavior, build setup, and other choices future contributors should preserve or understand.

## Bug-Fix Lessons

- After every bug fix, add a separate numbered lesson-learned note under `docs/lessons/` and update `docs/lessons/README.md`, following the format and naming convention documented there.
- Each lesson must record the symptom, root cause, fix, prevention rule for future development, and any regression test or safeguard added to prevent recurrence.
- Keep lesson notes separate from decision records: decisions document durable project choices, while lessons document reusable knowledge gained from defects.

## UI Interaction Rules

- All visible buttons must be clickable across their full visual surface, not only on their text, emoji, or icon. Native button styles can own their native hit areas; custom/plain SwiftUI buttons must fill their intended target and define a matching `contentShape`, or use a shared Routina visual modifier that does.

## Scrolling and Render-Path Performance

- Treat every SwiftUI `body`, row builder, section builder, toolbar builder, and computed property reached from them as a hot render path. They may run repeatedly during scrolling even when their apparent inputs have not changed.
- Never fetch SwiftData, walk complete model collections, rebuild dictionaries, group or sort all history, format every off-screen row, or call an expensive domain derivation directly from a scrolling render path.
- Build expensive list/timeline presentations only when source data, filters, search, calendar semantics, or visible preferences change. Cache the immutable result and let scrolling reuse it.
- Cache all related derived artifacts together when they share the same source, including filtered and unfiltered entries, grouped sections, lookup dictionaries, counts, and row numbers. Do not hide a second full-history pass behind a convenience computed property.
- Keep visible collections lazily rendered with stable semantic IDs. Avoid changing a list/container `.id` during normal updates because that discards native reuse and scroll position.
- Coalesce persistence and sync notifications. Defer nonessential snapshot refreshes while `RoutinaMacScrollInteractionGate.isScrollActive`, then refresh after the quiet window; never trade data correctness away permanently.
- Before merging a meaningful scrolling surface or data-pipeline change, test with production-like history volume in a Release build. Profile while continuously scrolling and verify that app-owned model filtering/grouping/fetching does not appear repeatedly in main-thread samples.
- Add a focused performance-regression test for the structural invariant whenever practical. Source-based regression checks are acceptable for guarding architectural boundaries that ordinary behavior tests cannot measure.
- Read [Decision 0418](docs/decisions/0418-keep-whole-history-work-out-of-scrolling-render-paths.md) before changing Timeline, Planner, Stats, or another unbounded scrolling surface.

## Build Verification

- Completion gate: never mark a task that changes application code, tests, project configuration, or build behavior as finished until the relevant automated tests have passed and the affected app has been built and launched successfully from that final change. Do not rely on results from before the final edit.
- For macOS or shared-code work, this means running `swift test -q`, building `RoutinaMacOSDev`, and launching the newly built macOS app. Treat a failed launch as an unfinished task: diagnose or clearly report the blocker instead of claiming completion.
- For iOS-only work, run the relevant tests, build the iOS development target, and launch the newly built app on its target simulator or device before finishing.
- Swift package tests:
  `swift test -q`
- iOS CLI build:
  `xcodebuild build -quiet -project /Users/ghadirianh/Routina/RoutinaiOS.xcodeproj -scheme RoutinaiOSDev -destination 'generic/platform=iOS'`
- macOS CLI build:
  `xcodebuild build -quiet -project /Users/ghadirianh/Routina/RoutinaMacOS.xcodeproj -scheme RoutinaMacOSDev -destination 'generic/platform=macOS'`
- If the macOS CLI build fails with a provisioning profile error like `profile doesn't include signing certificate`, retry once with `-allowProvisioningUpdates`:
  `xcodebuild build -quiet -allowProvisioningUpdates -project /Users/ghadirianh/Routina/RoutinaMacOS.xcodeproj -scheme RoutinaMacOSDev -destination 'generic/platform=macOS'`
- After a successful `-allowProvisioningUpdates` build, run the normal macOS build again to confirm the refreshed Xcode managed profiles are now valid without the extra flag.
- Prefer the quiet build and test commands for routine verification. Verbose Xcode 26.4 Swift builds can print internal `DecodingError.dataCorrupted` / `Corrupted JSON` messages while the build still succeeds; quiet commands keep real compiler errors visible without that noisy parseable-output decoder issue.
