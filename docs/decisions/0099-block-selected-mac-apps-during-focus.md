# 0099: Block Selected Mac Apps During Focus

## Status

Accepted

## Date

2026-05-29

## Context

Routina's iOS focus shield uses Screen Time APIs (`FamilyControls`, `ManagedSettings`, and `DeviceActivity`) to block user-selected apps, app categories, and websites while a focus timer is running.

Native macOS can import those framework modules, but the relevant authorization, picker, device activity, and managed settings types are unavailable to macOS apps in the current SDK. A native Mac app therefore cannot reuse the same private Screen Time token flow for website or category shielding.

## Decision

The macOS focus controls expose a Mac-specific focus blocker that stores user-selected app bundle identifiers and display names. While any task `FocusSession` is active, Routina watches running and newly launched apps and asks matching selected apps to quit. When there is no active task focus session, or when the Mac blocker is disabled or empty, the app blocker stops enforcing.

Mac website blocking remains unavailable in the native app until Routina adopts a separate macOS-capable mechanism, such as an approved Network Extension content filter or browser-specific extension path. The iOS Screen Time shield remains the only implementation that can block websites with opaque Apple tokens.

## Consequences

- Mac users can add local friction for selected distracting apps during task focus timers.
- Mac app blocking is best-effort and depends on macOS allowing Routina to ask the selected app to quit.
- Mac app selections use separate defaults from iOS Screen Time selections because the stored data and privacy model are different.
- Website blocking should not be presented as system-wide on macOS without a future decision and entitlement-backed implementation.
