# iOS Production Device Profiling Runbook

Use this runbook for performance investigations that must represent the
shipping iOS app on a physical device. It records the safeguards that avoid
profiling a development build, attaching to the wrong process, or interpreting
an empty trace.

The warm-but-disposable setup is defined by
[Decision 0566](decisions/0566-keep-production-ios-profiling-setup-warm-but-disposable.md).

## Guardrails

- Ask the device owner before taking a screenshot, screen recording, or screen
  capture. A CPU trace does not capture the screen.
- Use a device with production-like local history and allow normal CloudKit
  synchronization. Record any unusually large data set or active sync state in
  the investigation notes.
- Run one scenario per trace. Do not combine Home scrolling, Search activation,
  and typing into one unmarked recording.
- Before a final build, capture `git status --short` and identify any modified
  or untracked files that affect the target. Do not change another person's
  work just to make a build pass; resolve it with its owner or obtain explicit
  permission first.
- Device verification is revision-specific. After any source, configuration,
  dependency, or worktree change, rebuild, validate, install, and launch again
  before treating the app as verified. A previously installed app cannot
  verify later source.
- Keep every build product, trace, export, and temporary analysis helper under
  a uniquely named project-local `.codex/` profiling path, and delete them
  after the investigation.
- A shared project-local Swift package cache may persist at
  `.codex/IOSBuildPackageCache`. It must contain package download/repository
  cache data only—never app products, dSYMs, traces, exports, or analysis
  helpers.

## Fast start without weakening verification

The first fully isolated Release build can be slow because a new Derived Data
folder has no package checkouts, compiled dependencies, module cache, iOS app,
or Watch extension. A 2026-08-14 production profiling session took about 12
minutes to reach the launched app after it also made an avoidable sandboxed
build attempt and treated a command-wrapper return as possible build
completion while `xcodebuild` was still running.

Use these rules on later sessions:

1. Give `xcodebuild`, `devicectl`, and `xctrace` their required Xcode cache,
   signing, and device-service access on the first invocation. Do not make a
   restricted build attempt that is expected to fail and then repeat it.
2. Keep the session's Derived Data fresh, but pass the persistent
   `.codex/IOSBuildPackageCache` through `-packageCachePath`. Also pass
   `-skipPackageUpdates` and `-disableAutomaticPackageResolution` so the build
   follows the checked-in `Package.resolved` state without a speculative
   update.
3. Do not point `-clonedSourcePackagesDirPath` at a separate shared folder.
   Routina's Crashlytics build phase currently resolves its upload helper from
   the session Derived Data's `SourcePackages` directory. A separate checkout
   directory needs an independently implemented and verified build-system
   change before it is safe.
4. Wait for the actual `xcodebuild` PID or the original execution session to
   exit. A tool wrapper returning early is not completion. Do not probe for a
   partial `.app` while the build is still compiling.
5. As soon as the build exits successfully, validate, install, launch, and
   query the numeric PID without an idle gap.
6. Reuse that one validated app and matching dSYM for every baseline and
   scenario trace in the same unchanged-worktree session. Rebuild only after a
   source, configuration, dependency, signing, or relevant worktree change.

The shared package cache removes repeated dependency download/repository work;
it does not remove the clean optimized Release compilation required by this
runbook. If timing output still shows compilation as the dominant delay, do
not retain profiling Derived Data as an undocumented shortcut. Improving that
step requires a deliberate compiler-cache/build-system decision that preserves
the exact-binary and cleanup guarantees below.

## 1. Identify the exact production target and device

The target must be `RoutinaiOSProd` in the `Release` configuration. Its bundle
identifier is `ir.hamedgh.Routinam`.

The device-control identifier and the Instruments trace UDID can differ. Record
both rather than reusing one blindly.

```zsh
xcrun devicectl list devices
xcrun xctrace list devices
```

Set the values below only after confirming that they refer to the same physical
device:

```zsh
DEVICE_CONTROL_ID='<devicectl identifier>'
DEVICE_TRACE_UDID='<xctrace UDID>'
PROFILE_ROOT='/Users/ghadirianh/Routina/.codex/IOSProductionProfile'
PACKAGE_CACHE_ROOT='/Users/ghadirianh/Routina/.codex/IOSBuildPackageCache'
APP_PATH="$PROFILE_ROOT/Build/Products/Release-iphoneos/Routinam.app"
```

## 2. Build and validate the real Release app

Freeze the exact source state before building and record it with the scenario:

```zsh
git status --short
git rev-parse HEAD
```

If unexpected changes affect the target, stop and resolve ownership before
building. Do not silently remove, edit, or exclude untracked work.

Build the production scheme into a fresh, profiling-only Derived Data folder:

```zsh
mkdir -p "$PACKAGE_CACHE_ROOT"

xcodebuild build -quiet \
  -project /Users/ghadirianh/Routina/RoutinaiOS.xcodeproj \
  -scheme RoutinaiOSProd \
  -configuration Release \
  -destination "id=$DEVICE_TRACE_UDID" \
  -derivedDataPath "$PROFILE_ROOT" \
  -packageCachePath "$PACKAGE_CACHE_ROOT" \
  -skipPackageUpdates \
  -disableAutomaticPackageResolution \
  -showBuildTimingSummary
```

Do not assume a command wrapper returning means the build is finished. Wait for
the actual `xcodebuild` process or its original execution session to end. If a
wrapper detaches, find the exact build PID once and wait on it instead of
repeatedly guessing from the presence of partial output. Then verify the
product before installing it:

```zsh
test -x "$APP_PATH/Routinam"
plutil -extract CFBundleIdentifier raw -o - "$APP_PATH/Info.plist"
dwarfdump --uuid "$APP_PATH/Routinam"
dwarfdump --uuid "$APP_PATH.dSYM/Contents/Resources/DWARF/Routinam"
```

The identifier must be `ir.hamedgh.Routinam`; the executable and dSYM UUIDs
must match. A partial `.app` directory without `Info.plist` or the executable
is a failed build, not an installable product. Do not substitute the development
scheme or bundle.

## 3. Install, launch, and select the exact process

```zsh
xcrun devicectl device install app --device "$DEVICE_CONTROL_ID" "$APP_PATH"
xcrun devicectl device process launch --device "$DEVICE_CONTROL_ID" ir.hamedgh.Routinam
xcrun devicectl device info processes --device "$DEVICE_CONTROL_ID"
```

Find the numeric PID whose path ends in `Routinam.app/Routinam`. Attach using
that PID only. Never attach by the name `Routinam`: a development build with a
similar name can make the attachment ambiguous or select the wrong process.

## 4. Capture one scenario at a time

First capture a 20-second idle baseline after the app has settled. Then use a
fresh trace for each of the following paths:

1. Home: settle for five seconds, then continuously scroll Home for 15 seconds.
2. Search activation: settle on Home, tap Search once, and wait for the
   keyboard and transition to finish without typing.
3. Search typing: settle in Search, type a known 8- to 12-character query at a
   natural pace, wait two seconds, then clear it.

Tell the person exactly which single path to perform before starting each
recording. Record the scenario name, start/end time, device model/OS, app build
number, and whether CloudKit was actively importing. This gives each call tree
an unambiguous interaction window without screen recording.

Start with a direct, numeric-PID Time Profiler trace:

```zsh
TRACE="$PROFILE_ROOT/SearchTyping.trace"
xcrun xctrace record \
  --template 'Time Profiler' \
  --device "$DEVICE_TRACE_UDID" \
  --attach '<numeric production PID>' \
  --output "$TRACE" \
  --time-limit 30s \
  --no-prompt
```

Retain the execution session and wait for the actual `xctrace` process to exit.
`Reached specified time limit, ending recording` means sampling has stopped,
not that the trace bundle is ready. Do not export until the process reports
`Output file saved` and exits successfully; exporting during the save phase can
produce a missing-template document or an invalid empty stream.

## 5. Validate the trace before interpreting it

Export the table of contents and the call tree. A `time-profile` table listed
in the table of contents is not proof that it contains samples.

```zsh
TOC="$PROFILE_ROOT/SearchTyping-toc.xml"
CALL_TREE="$PROFILE_ROOT/SearchTyping-call-tree.xml"

xcrun xctrace export --input "$TRACE" --toc --output "$TOC"
xcrun xctrace export \
  --input "$TRACE" \
  --xpath '/trace-toc/run[@number="1"]/data/table[@schema="time-profile"]' \
  --output "$CALL_TREE"

wc -c "$CALL_TREE"
rg 'Routinam' "$CALL_TREE"
```

Only analyze the direct trace when the call-tree export is non-empty and
contains Routinam samples. If it does not, discard it as an attachment failure;
do not infer a performance result from the trace metadata.

Some device/Xcode pairings can produce an empty direct-attachment stream even
with a valid `get-task-allow` entitlement. In that case, repeat the same,
single scenario with the all-process fallback and isolate Routinam in the
exported call tree:

```zsh
TRACE="$PROFILE_ROOT/SearchTyping-all-processes.trace"
xcrun xctrace record \
  --template 'Time Profiler' \
  --device "$DEVICE_TRACE_UDID" \
  --all-processes \
  --output "$TRACE" \
  --time-limit 30s \
  --no-prompt
```

Export `time-profile` again, not only raw `time-sample` data. The call-tree
export is symbolicated and is the primary artifact for identifying app-owned
main-thread work. If symbols are missing, recheck the matching Release dSYM
before drawing conclusions.

## 6. Analyze and report correctly

- Focus on Routinam's **Main Thread**. Look for app-owned SwiftData fetches,
  model scans, maintenance, filtering, sorting, grouping, snapshot building,
  and SwiftUI/List construction that coincide with the scenario window.
- Compare the baseline with the matching interaction trace. A burst that drains
  after a sync or presentation update is different from a continuously busy
  idle app.
- Treat stack-category times as inclusive and overlapping. Do not add them
  together or present them as exclusive wall-clock time.
- Link each conclusion to the sampled function and the responsible source path.
  Distinguish observed facts from likely triggering mechanisms.
- Check that inactive tabs and notification observers did not consume the
  captured main-thread time while the target scenario was active.

## 7. Mandatory cleanup

At the end of every profiling session, remove the profiling-only Derived Data
folder, all `.trace` bundles, call-tree/TOC/XML exports, and any temporary
analysis helper or log. Then verify none remain and report the exact artifacts
removed.

```zsh
rm -rf /Users/ghadirianh/Routina/.codex/IOSProductionProfile
test ! -e /Users/ghadirianh/Routina/.codex/IOSProductionProfile
```

The final command must succeed. Keep every session artifact under this one
dedicated directory; do not scan for or remove another investigation's files.
Do not remove `.codex/IOSBuildPackageCache` as part of session cleanup because
it contains no build product, symbol, trace, export, or investigation result.
