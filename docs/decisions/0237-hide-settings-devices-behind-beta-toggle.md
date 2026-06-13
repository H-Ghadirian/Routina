# 0237: Hide Settings Devices Behind Beta Toggle

## Status

Accepted

## Date

2026-06-13

## Context

Routina records per-installation device sessions and can show them in Settings. The Devices section is useful for validating multi-device behavior, but it is not yet part of the default settings surface users need day to day.

## Decision

Settings -> Devices remains implemented, but it is hidden by default. Users can enable it from Settings -> General -> Beta Experiments with the Show Devices section toggle.

## Consequences

- New installs do not show the Devices section in Settings unless the beta toggle is enabled.
- Existing device session recording can continue independently of Settings navigation visibility.
- Both standalone Settings and embedded Mac Home Settings must use the same visibility preference.
